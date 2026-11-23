use rect_packer::DensePacker;
use serde::{Deserialize, Serialize};

#[inline]
fn next_pow2(n: i32) -> i32 {
    2i32.pow((n as f32).log2().ceil() as _)
}

pub struct AtlasBuilder {
    max_size: i32,
    packers: Vec<DensePacker>,
    textures: Vec<(AtlasRect, Box<[u8]>)>,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
pub struct AtlasRef(pub i32);

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
#[repr(C)]
pub struct AtlasRect {
    pub(super) atlas_id: u32,

    pub(super) x: i32,
    pub(super) y: i32,
    pub(super) w: i32,
    pub(super) h: i32,

    // Normalized to 0-1 by texture width and height
    pub(super) origin_x: f32,
    pub(super) origin_y: f32,

    /// SUNKY-IOS: size of the pixels actually stored in the atlas, when an image bigger than the
    /// GPU allows was shrunk to fit (0 = same as w/h). w/h stay the image's real size, so it's
    /// still drawn at its real size; only sampling uses these.
    #[serde(default)]
    pub(super) tex_w: i32,
    #[serde(default)]
    pub(super) tex_h: i32,
}

impl AtlasRect {
    pub(super) fn texel_w(&self) -> i32 {
        if self.tex_w > 0 { self.tex_w } else { self.w }
    }
    pub(super) fn texel_h(&self) -> i32 {
        if self.tex_h > 0 { self.tex_h } else { self.h }
    }
}

/// SUNKY-IOS: shrinks a 4-byte-per-pixel image to (nw, nh) by averaging the pixels each one covers.
fn shrink(data: &[u8], w: i32, h: i32, nw: i32, nh: i32) -> Box<[u8]> {
    let mut out = vec![0u8; (nw * nh * 4) as usize];
    for ny in 0..nh {
        let y0 = (ny as i64 * h as i64 / nh as i64) as i32;
        let y1 = (((ny + 1) as i64 * h as i64 / nh as i64) as i32).max(y0 + 1).min(h);
        for nx in 0..nw {
            let x0 = (nx as i64 * w as i64 / nw as i64) as i32;
            let x1 = (((nx + 1) as i64 * w as i64 / nw as i64) as i32).max(x0 + 1).min(w);
            let mut acc = [0u32; 4];
            let mut n = 0u32;
            for y in y0..y1 {
                for x in x0..x1 {
                    let i = ((y * w + x) * 4) as usize;
                    for c in 0..4 {
                        acc[c] += data[i + c] as u32;
                    }
                    n += 1;
                }
            }
            let o = ((ny * nw + nx) * 4) as usize;
            for c in 0..4 {
                out[o + c] = (acc[c] / n.max(1)) as u8;
            }
        }
    }
    out.into_boxed_slice()
}

impl AtlasBuilder {
    pub fn new(max_size: i32) -> Self {
        assert_eq!(max_size, next_pow2(max_size));
        AtlasBuilder { max_size, packers: Vec::new(), textures: Vec::new() }
    }

    pub fn texture(
        &mut self,
        width: i32,
        height: i32,
        origin_x: i32,
        origin_y: i32,
        data: Box<[u8]>,
    ) -> Option<AtlasRef> {
        fn to_texture(
            id: u32,
            rect: rect_packer::Rect,
            data: Box<[u8]>,
            origin_x: i32,
            origin_y: i32,
        ) -> (AtlasRect, Box<[u8]>) {
            (
                AtlasRect {
                    atlas_id: id,
                    w: rect.width,
                    h: rect.height,
                    x: rect.x,
                    y: rect.y,
                    origin_x: (origin_x as f32 / rect.width as f32),
                    origin_y: (origin_y as f32 / rect.height as f32),
                    tex_w: 0,
                    tex_h: 0,
                },
                data,
            )
        }

        if width <= 0 || height <= 0 {
            return Some(AtlasRef(-1))
        }

        if width > self.max_size || height > self.max_size {
            // SUNKY-IOS: too big for the GPU (Part 3 has a 5000px background; iPhones allow 4096).
            // Store it shrunk to fit and remember its real size, instead of failing.
            let nw = width.min(self.max_size);
            let nh = height.min(self.max_size);
            let small = shrink(&data, width, height, nw, nh);
            let id = self.texture(nw, nh, 0, 0, small)?;
            let (rect, _) = &mut self.textures[id.0 as usize];
            rect.tex_w = nw;
            rect.tex_h = nh;
            rect.w = width;
            rect.h = height;
            rect.origin_x = origin_x as f32 / width as f32;
            rect.origin_y = origin_y as f32 / height as f32;
            eprintln!("image {}x{} is bigger than the GPU allows, stored at {}x{}", width, height, nw, nh);
            return Some(id)
        }

        for (id, packer) in self.packers.iter_mut().enumerate() {
            if let Some(rect) = packer.pack(width, height, false) {
                let (atlas_ref, data) = to_texture(id as _, rect, data, origin_x, origin_y);
                let id = self.textures.len() as i32;
                self.textures.push((atlas_ref.clone(), data));
                return Some(AtlasRef(id))
            } else {
                loop {
                    let (pwidth, pheight) = packer.size();
                    if pwidth <= pheight && (pwidth * 2) <= self.max_size {
                        packer.resize(pwidth * 2, pheight);
                    } else if (pheight * 2) <= self.max_size {
                        packer.resize(pwidth, pheight * 2);
                    } else {
                        break
                    }

                    if let Some(rect) = packer.pack(width, height, false) {
                        let (atlas_ref, data) = to_texture(id as _, rect, data, origin_x, origin_y);
                        let id = self.textures.len() as i32;
                        self.textures.push((atlas_ref.clone(), data));
                        return Some(AtlasRef(id))
                    }
                }
            }
        }

        let size = 4096.min(self.max_size);
        self.packers.push(DensePacker::new(size, size));
        self.texture(width, height, origin_x, origin_y, data)
    }

    #[allow(clippy::type_complexity)] // It's for the Renderer only.
    pub(super) fn into_inner(self) -> (Vec<DensePacker>, Vec<(AtlasRect, Box<[u8]>)>) {
        (self.packers, self.textures)
    }
}
