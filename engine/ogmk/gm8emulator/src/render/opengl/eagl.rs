// SUNKY-IOS: OpenGL ES 3.0 on iPhone.
//
// The iPhone app (ios/App/GameView.m) owns the CAEAGLLayer. On the runner thread it creates an
// EAGLContext, makes it current and builds a framebuffer whose colour buffer is the layer's
// renderbuffer. That framebuffer stands in for the window's framebuffer 0 (see gles.rs).

use super::gles::SCREEN_FBO;
use ramen::{connection::Connection, window::Window};
use std::{ffi::c_void, sync::atomic::Ordering};

extern "C" {
    /// Creates the context on this thread and returns the screen framebuffer (0 on failure).
    fn sunky_gl_setup() -> u32;
    /// Presents the layer's renderbuffer.
    fn sunky_gl_present();
    /// Releases the context (game ended).
    fn sunky_gl_teardown();
}

pub struct PlatformImpl {
    _private: (),
}

impl PlatformImpl {
    pub unsafe fn new(_connection: &Connection, _window: &Window) -> Result<Self, String> {
        let fbo = sunky_gl_setup();
        if fbo == 0 {
            return Err("couldn't create the OpenGL ES context".into())
        }
        SCREEN_FBO.store(fbo, Ordering::Relaxed);
        Ok(PlatformImpl { _private: () })
    }

    pub unsafe fn get_function_loader() -> Result<Box<dyn FnMut(&'static str) -> *const c_void>, String> {
        Ok(Box::new(|name: &'static str| unsafe {
            let c = std::ffi::CString::new(name).unwrap();
            libc::dlsym(libc::RTLD_DEFAULT, c.as_ptr()) as *const c_void
        }))
    }

    pub unsafe fn clean_function_loader() {}

    pub unsafe fn swap_buffers(&self) {
        sunky_gl_present();
    }

    pub unsafe fn set_swap_interval(&self, _n: u32) -> bool {
        true
    }

    pub unsafe fn get_swap_interval(&self) -> u32 {
        1
    }

    pub unsafe fn wait_vsync(&self) {}
}

impl Drop for PlatformImpl {
    fn drop(&mut self) {
        unsafe { sunky_gl_teardown() };
        SCREEN_FBO.store(0, Ordering::Relaxed);
    }
}
