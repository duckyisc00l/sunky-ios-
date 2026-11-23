//! SUNKY-IOS: replacement artwork.
//!
//! If the environment variable SUNKY_OVERRIDES names a folder, images in it replace the game's own
//! art when the game loads (the game files are never changed):
//!   <folder>/sprites/<sprite name>/<frame number>.png
//!   <folder>/backgrounds/<background name>.png
//! A replacement must be the same size as the original. Used to make on-screen instructions talk
//! about the phone's buttons instead of keyboard keys.

use gm8exe::GameAssets;
use std::path::Path;

fn load_bgra(path: &Path, w: u32, h: u32) -> Option<Box<[u8]>> {
    let img = image::open(path).ok()?.to_rgba8();
    if img.width() != w || img.height() != h {
        eprintln!("override {:?} is {}x{}, needs {}x{}", path, img.width(), img.height(), w, h);
        return None
    }
    let mut data = img.into_raw();
    for px in data.chunks_exact_mut(4) {
        px.swap(0, 2); // RGBA -> BGRA, as GameMaker stores it
    }
    Some(data.into_boxed_slice())
}

pub fn apply(assets: &mut GameAssets) {
    let dir = match std::env::var_os("SUNKY_OVERRIDES") {
        Some(d) => std::path::PathBuf::from(d),
        None => return,
    };
    let mut count = 0;
    for sprite in assets.sprites.iter_mut().flatten() {
        let folder = dir.join("sprites").join(sprite.name.to_string());
        if !folder.is_dir() {
            continue
        }
        for (i, frame) in sprite.frames.iter_mut().enumerate() {
            if let Some(data) = load_bgra(&folder.join(format!("{}.png", i)), frame.width, frame.height) {
                frame.data = data;
                count += 1;
            }
        }
    }
    for bg in assets.backgrounds.iter_mut().flatten() {
        let file = dir.join("backgrounds").join(format!("{}.png", bg.name));
        if file.is_file() {
            if let Some(data) = load_bgra(&file, bg.width, bg.height) {
                bg.data = Some(data);
                count += 1;
            }
        }
    }
    eprintln!("replacement art: {} images from {:?}", count, dir);
}
