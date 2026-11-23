// SUNKY-IOS: OpenGL ES 3.0 context through EGL on Linux/X11.
// Only used by the Linux lab's `gles` build, to test the iPhone renderer path without a Mac.
#![allow(non_snake_case, non_camel_case_types, dead_code)]

use ramen::{connection::Connection, window::Window};
use std::{ffi::c_void, os::raw::{c_char, c_int, c_uint}};

type EGLDisplay = *mut c_void;
type EGLConfig = *mut c_void;
type EGLContext = *mut c_void;
type EGLSurface = *mut c_void;
type EGLint = c_int;
type EGLBoolean = c_uint;

const EGL_NONE: EGLint = 0x3038;
const EGL_RED_SIZE: EGLint = 0x3024;
const EGL_GREEN_SIZE: EGLint = 0x3023;
const EGL_BLUE_SIZE: EGLint = 0x3022;
const EGL_ALPHA_SIZE: EGLint = 0x3021;
const EGL_DEPTH_SIZE: EGLint = 0x3025;
const EGL_STENCIL_SIZE: EGLint = 0x3026;
const EGL_SURFACE_TYPE: EGLint = 0x3033;
const EGL_WINDOW_BIT: EGLint = 0x0004;
const EGL_RENDERABLE_TYPE: EGLint = 0x3040;
const EGL_OPENGL_ES3_BIT: EGLint = 0x0040;
const EGL_NATIVE_VISUAL_ID: EGLint = 0x302E;
const EGL_CONTEXT_CLIENT_VERSION: EGLint = 0x3098;
const EGL_OPENGL_ES_API: c_uint = 0x30A0;

#[link(name = "EGL")]
extern "C" {
    fn eglGetDisplay(native: *mut c_void) -> EGLDisplay;
    fn eglInitialize(dpy: EGLDisplay, major: *mut EGLint, minor: *mut EGLint) -> EGLBoolean;
    fn eglBindAPI(api: c_uint) -> EGLBoolean;
    fn eglChooseConfig(dpy: EGLDisplay, attrib: *const EGLint, configs: *mut EGLConfig, size: EGLint, num: *mut EGLint) -> EGLBoolean;
    fn eglGetConfigAttrib(dpy: EGLDisplay, config: EGLConfig, attr: EGLint, value: *mut EGLint) -> EGLBoolean;
    fn eglCreateContext(dpy: EGLDisplay, config: EGLConfig, share: EGLContext, attrib: *const EGLint) -> EGLContext;
    fn eglCreateWindowSurface(dpy: EGLDisplay, config: EGLConfig, win: usize, attrib: *const EGLint) -> EGLSurface;
    fn eglMakeCurrent(dpy: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) -> EGLBoolean;
    fn eglSwapBuffers(dpy: EGLDisplay, surface: EGLSurface) -> EGLBoolean;
    fn eglSwapInterval(dpy: EGLDisplay, interval: EGLint) -> EGLBoolean;
    fn eglGetProcAddress(name: *const c_char) -> *mut c_void;
    fn eglGetError() -> EGLint;
}

static mut LOAD_BUF: Vec<u8> = Vec::new();

pub struct PlatformImpl {
    display: EGLDisplay,
    surface: EGLSurface,
    interval: std::cell::Cell<u32>,
}

impl PlatformImpl {
    pub unsafe fn new(connection: &Connection, window: &Window) -> Result<Self, String> {
        let display = eglGetDisplay(connection.xdisplay().cast());
        if display.is_null() {
            return Err("eglGetDisplay failed".into())
        }
        let (mut maj, mut min) = (0, 0);
        if eglInitialize(display, &mut maj, &mut min) == 0 {
            return Err(format!("eglInitialize failed: {:#x}", eglGetError()))
        }
        eglBindAPI(EGL_OPENGL_ES_API);
        let attribs = [
            EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
            EGL_DEPTH_SIZE, 24, EGL_STENCIL_SIZE, 8,
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_NONE,
        ];
        let mut configs = [std::ptr::null_mut(); 64];
        let mut n = 0;
        if eglChooseConfig(display, attribs.as_ptr(), configs.as_mut_ptr(), 64, &mut n) == 0 || n == 0 {
            return Err(format!("eglChooseConfig found nothing: {:#x}", eglGetError()))
        }
        // Prefer the config whose X visual matches the one the window was made with (from GLX).
        let want_visual = crate::render::opengl::glx::GLX.as_ref().map(|g| g.visual as EGLint).unwrap_or(-1);
        let mut config = configs[0];
        for &c in &configs[..n as usize] {
            let mut v = 0;
            eglGetConfigAttrib(display, c, EGL_NATIVE_VISUAL_ID, &mut v);
            if v == want_visual {
                config = c;
                break
            }
        }
        let ctx_attribs = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE];
        let context = eglCreateContext(display, config, std::ptr::null_mut(), ctx_attribs.as_ptr());
        if context.is_null() {
            return Err(format!("eglCreateContext failed: {:#x}", eglGetError()))
        }
        let surface = eglCreateWindowSurface(display, config, window.xid() as usize, std::ptr::null());
        if surface.is_null() {
            return Err(format!("eglCreateWindowSurface failed: {:#x}", eglGetError()))
        }
        if eglMakeCurrent(display, surface, surface, context) == 0 {
            return Err(format!("eglMakeCurrent failed: {:#x}", eglGetError()))
        }
        eprintln!("EGL {}.{} ES 3 context ready", maj, min);
        Ok(PlatformImpl { display, surface, interval: std::cell::Cell::new(1) })
    }

    pub unsafe fn get_function_loader() -> Result<Box<dyn FnMut(&'static str) -> *const c_void>, String> {
        let mut lib = libc::dlopen("libGLESv2.so.2\0".as_ptr().cast(), libc::RTLD_GLOBAL | libc::RTLD_NOW);
        if lib.is_null() {
            lib = libc::dlopen("libGLESv2.so\0".as_ptr().cast(), libc::RTLD_GLOBAL | libc::RTLD_NOW);
        }
        Ok(Box::new(move |name: &'static str| unsafe {
            LOAD_BUF.clear();
            LOAD_BUF.extend_from_slice(name.as_bytes());
            LOAD_BUF.push(0);
            let mut s = if lib.is_null() { std::ptr::null_mut() } else { libc::dlsym(lib, LOAD_BUF.as_ptr().cast()) };
            if s.is_null() {
                s = eglGetProcAddress(LOAD_BUF.as_ptr().cast());
            }
            s as *const c_void
        }) as _)
    }

    pub unsafe fn clean_function_loader() {
        LOAD_BUF = Vec::new();
    }

    pub unsafe fn swap_buffers(&self) {
        eglSwapBuffers(self.display, self.surface);
    }

    pub unsafe fn set_swap_interval(&self, n: u32) -> bool {
        self.interval.set(n);
        eglSwapInterval(self.display, n as _) != 0
    }

    pub unsafe fn get_swap_interval(&self) -> u32 {
        self.interval.get()
    }

    pub unsafe fn wait_vsync(&self) {}
}
