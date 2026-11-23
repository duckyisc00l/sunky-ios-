// SUNKY-IOS: OpenGL ES 3.0 compatibility layer.
//
// The renderer is written against desktop OpenGL 3.3 core. This module exposes the same `gl::Gl`
// interface on top of OpenGL ES 3.0 bindings: almost every call is forwarded through `Deref`, and the
// handful that ES lacks or treats differently are re-implemented here as inherent methods (which Rust
// picks before the deref'd ones):
//
// - GetTexLevelParameteriv (ES 3.1+): texture sizes are tracked when textures are created.
// - GetTexImage (desktop only): the texture is attached to a scratch framebuffer and read back.
// - BGRA uploads: pixels are swizzled to RGBA on the CPU.
// - Depth textures: ES needs an integer type, not FLOAT.
// - ProvokingVertex (desktop only): ignored. Only flat-shaded 3D lighting relies on it.
// - ReadBuffer(BACK) on a window without a default framebuffer: ignored.
// - Framebuffer 0: on iOS the "screen" is a renderbuffer-backed FBO, so binding 0 binds that instead.
#![allow(non_snake_case, clippy::all, dead_code)]

pub use self::raw::*;
use std::{cell::RefCell, collections::HashMap, ops::Deref, os::raw::c_void};

mod raw {
    include!(concat!(env!("OUT_DIR"), "/gl_bindings.rs"));
}

// Desktop-only enums the renderer names.
pub const BGRA: types::GLenum = 0x80E1;
pub const TEXTURE_WIDTH: types::GLenum = 0x1000;
pub const TEXTURE_HEIGHT: types::GLenum = 0x1001;
pub const FIRST_VERTEX_CONVENTION: types::GLenum = 0x8E4D;

/// The framebuffer that stands in for "the window" (0 everywhere except iOS).
pub static SCREEN_FBO: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);

pub struct Gl {
    raw: raw::Gl,
    sizes: RefCell<HashMap<types::GLuint, (types::GLint, types::GLint)>>,
    scratch_fbo: RefCell<types::GLuint>,
}

impl Deref for Gl {
    type Target = raw::Gl;
    fn deref(&self) -> &raw::Gl {
        &self.raw
    }
}

impl Gl {
    pub fn load_with<F>(loadfn: F) -> Gl
    where
        F: FnMut(&'static str) -> *const c_void,
    {
        Gl { raw: raw::Gl::load_with(loadfn), sizes: RefCell::new(HashMap::new()), scratch_fbo: RefCell::new(0) }
    }

    unsafe fn bound_texture(&self) -> types::GLuint {
        let mut t: types::GLint = 0;
        self.raw.GetIntegerv(TEXTURE_BINDING_2D, &mut t);
        t as types::GLuint
    }

    pub unsafe fn TexImage2D(
        &self,
        target: types::GLenum,
        level: types::GLint,
        internalformat: types::GLint,
        width: types::GLsizei,
        height: types::GLsizei,
        border: types::GLint,
        format: types::GLenum,
        ty: types::GLenum,
        pixels: *const c_void,
    ) {
        if level == 0 {
            let t = self.bound_texture();
            self.sizes.borrow_mut().insert(t, (width, height));
        }
        if format == DEPTH_COMPONENT {
            // ES: DEPTH_COMPONENT16/24 textures take UNSIGNED_INT data
            let internal = if internalformat as types::GLenum == DEPTH_COMPONENT16 {
                DEPTH_COMPONENT16
            } else {
                DEPTH_COMPONENT24
            };
            self.raw.TexImage2D(target, level, internal as _, width, height, border, DEPTH_COMPONENT, UNSIGNED_INT, std::ptr::null());
            return;
        }
        if format == BGRA && !pixels.is_null() {
            let n = (width.max(0) as usize) * (height.max(0) as usize) * 4;
            let mut buf = std::slice::from_raw_parts(pixels as *const u8, n).to_vec();
            for px in buf.chunks_exact_mut(4) {
                px.swap(0, 2);
            }
            self.raw.TexImage2D(target, level, RGBA8 as _, width, height, border, RGBA, ty, buf.as_ptr().cast());
            return;
        }
        let internal = if internalformat as types::GLenum == RGBA { RGBA8 as types::GLint } else { internalformat };
        let format = if format == BGRA { RGBA } else { format };
        self.raw.TexImage2D(target, level, internal, width, height, border, format, ty, pixels);
    }

    pub unsafe fn TexSubImage2D(
        &self,
        target: types::GLenum,
        level: types::GLint,
        xoffset: types::GLint,
        yoffset: types::GLint,
        width: types::GLsizei,
        height: types::GLsizei,
        format: types::GLenum,
        ty: types::GLenum,
        pixels: *const c_void,
    ) {
        if format == BGRA && !pixels.is_null() {
            let n = (width.max(0) as usize) * (height.max(0) as usize) * 4;
            let mut buf = std::slice::from_raw_parts(pixels as *const u8, n).to_vec();
            for px in buf.chunks_exact_mut(4) {
                px.swap(0, 2);
            }
            self.raw.TexSubImage2D(target, level, xoffset, yoffset, width, height, RGBA, ty, buf.as_ptr().cast());
        } else {
            self.raw.TexSubImage2D(target, level, xoffset, yoffset, width, height, format, ty, pixels);
        }
    }

    pub unsafe fn CopyTexImage2D(
        &self,
        target: types::GLenum,
        level: types::GLint,
        internalformat: types::GLenum,
        x: types::GLint,
        y: types::GLint,
        width: types::GLsizei,
        height: types::GLsizei,
        border: types::GLint,
    ) {
        if level == 0 {
            let t = self.bound_texture();
            self.sizes.borrow_mut().insert(t, (width, height));
        }
        // ES only copies into formats the read framebuffer can supply; RGBA8 framebuffers give RGBA.
        self.raw.CopyTexImage2D(target, level, internalformat, x, y, width, height, border);
    }

    pub unsafe fn DeleteTextures(&self, n: types::GLsizei, textures: *const types::GLuint) {
        {
            let mut sizes = self.sizes.borrow_mut();
            for t in std::slice::from_raw_parts(textures, n.max(0) as usize) {
                sizes.remove(t);
            }
        }
        self.raw.DeleteTextures(n, textures);
    }

    pub unsafe fn GetTexLevelParameteriv(
        &self,
        _target: types::GLenum,
        _level: types::GLint,
        pname: types::GLenum,
        params: *mut types::GLint,
    ) {
        let t = self.bound_texture();
        let (w, h) = self.sizes.borrow().get(&t).copied().unwrap_or((0, 0));
        *params = match pname {
            TEXTURE_WIDTH => w,
            TEXTURE_HEIGHT => h,
            _ => 0,
        };
    }

    /// Reads the bound texture through a scratch framebuffer. Depth reads give zeroes (ES can't read depth).
    pub unsafe fn GetTexImage(
        &self,
        _target: types::GLenum,
        _level: types::GLint,
        format: types::GLenum,
        ty: types::GLenum,
        pixels: *mut c_void,
    ) {
        let t = self.bound_texture();
        let (w, h) = self.sizes.borrow().get(&t).copied().unwrap_or((0, 0));
        if format == DEPTH_COMPONENT {
            let n = (w.max(0) as usize) * (h.max(0) as usize) * if ty == FLOAT { 4 } else { 4 };
            std::ptr::write_bytes(pixels as *mut u8, 0, n);
            return;
        }
        let mut prev: types::GLint = 0;
        self.raw.GetIntegerv(READ_FRAMEBUFFER_BINDING, &mut prev);
        let mut fbo = *self.scratch_fbo.borrow();
        if fbo == 0 {
            self.raw.GenFramebuffers(1, &mut fbo);
            *self.scratch_fbo.borrow_mut() = fbo;
        }
        self.raw.BindFramebuffer(READ_FRAMEBUFFER, fbo);
        self.raw.FramebufferTexture2D(READ_FRAMEBUFFER, COLOR_ATTACHMENT0, TEXTURE_2D, t, 0);
        self.raw.ReadPixels(0, 0, w, h, RGBA, UNSIGNED_BYTE, pixels);
        if format == BGRA {
            let n = (w.max(0) as usize) * (h.max(0) as usize) * 4;
            for px in std::slice::from_raw_parts_mut(pixels as *mut u8, n).chunks_exact_mut(4) {
                px.swap(0, 2);
            }
        }
        self.raw.FramebufferTexture2D(READ_FRAMEBUFFER, COLOR_ATTACHMENT0, TEXTURE_2D, 0, 0);
        self.raw.BindFramebuffer(READ_FRAMEBUFFER, prev as _);
    }

    pub unsafe fn ProvokingVertex(&self, _mode: types::GLenum) {}

    pub unsafe fn ReadBuffer(&self, src: types::GLenum) {
        if src != BACK {
            self.raw.ReadBuffer(src);
        }
    }

    pub unsafe fn BindFramebuffer(&self, target: types::GLenum, framebuffer: types::GLuint) {
        let fb = if framebuffer == 0 { SCREEN_FBO.load(std::sync::atomic::Ordering::Relaxed) } else { framebuffer };
        self.raw.BindFramebuffer(target, fb);
    }
}
