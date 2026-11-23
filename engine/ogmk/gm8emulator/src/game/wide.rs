//! SUNKY-IOS: widescreen.
//!
//! In rooms with one scrolling camera, the camera is widened to the screen's shape while drawing,
//! so more of the level shows at the sides instead of black bars. Game logic never sees this: the
//! view goes back to its real size as soon as drawing is done. Draw events do see the wide view, so
//! HUDs placed with view_xview/view_wview move out to the real screen edges.
//!
//! It is skipped (the game looks normal) where widening would look wrong: rooms without views
//! (menus, title cards, cutscenes), more than one visible view, rotated views, views that don't fill
//! the window, and rooms that are too narrow to show anything extra.

use super::view::View;
use std::sync::atomic::{AtomicU64, Ordering};

/// Framebuffer size the renderer currently has (w << 32 | h), as far as this module knows.
static FB: AtomicU64 = AtomicU64::new(0);

pub struct Plan {
    pub view: usize,
    pub src_x: i32,
    pub src_w: i32,
    pub port_w: u32,
    /// How far right the original view starts inside the wide picture, in window pixels.
    pub offset: u32,
}

/// Screen aspect to widen to, or None when widescreen is off.
fn target_aspect() -> Option<f64> {
    #[cfg(target_os = "ios")]
    {
        let (w, h, on) = ramen::platform::ios::widescreen_target();
        if on && w > 0 && h > 0 { Some(w as f64 / h as f64) } else { None }
    }
    #[cfg(not(target_os = "ios"))]
    {
        // Lab: SUNKY_WIDE=2.16 tests a phone-shaped screen on Linux.
        std::env::var("SUNKY_WIDE").ok()?.parse().ok()
    }
}

pub fn plan(views_enabled: bool, views: &[View], room_w: i32, win_w: u32, win_h: u32) -> Option<Plan> {
    let aspect = target_aspect()?;
    if !views_enabled || win_w == 0 || win_h == 0 {
        return None
    }
    let mut visible = views.iter().enumerate().filter(|(_, v)| v.visible);
    let (idx, v) = visible.next()?;
    if visible.next().is_some() {
        return None // split screen
    }
    let angle: f64 = v.angle.into();
    if angle != 0.0 || v.port_x != 0 || v.port_y != 0 || v.port_w != win_w || v.port_h != win_h {
        return None
    }
    if v.source_w <= 0 || v.port_w == 0 {
        return None
    }
    let want_port_w = (win_h as f64 * aspect).round() as i64;
    if want_port_w <= win_w as i64 + 2 {
        return None // already as wide as the screen
    }
    let extra_src = ((want_port_w - win_w as i64) * v.source_w as i64 / v.port_w as i64) as i32;
    let src_w = (v.source_w + extra_src).min(room_w);
    if src_w <= v.source_w + 1 {
        return None // room too narrow
    }
    let port_w = (src_w as i64 * v.port_w as i64 / v.source_w as i64) as u32;
    // Centre the extra space on the real view, then keep it inside the room.
    let src_x = (v.source_x - (src_w - v.source_w) / 2).max(0).min(room_w - src_w);
    let offset = ((v.source_x - src_x) as i64 * v.port_w as i64 / v.source_w as i64) as u32;
    Some(Plan { view: idx, src_x, src_w, port_w, offset })
}

/// Called whenever the game itself resizes the framebuffer.
pub fn note_fb(w: u32, h: u32) {
    FB.store(((w as u64) << 32) | h as u64, Ordering::Relaxed);
}

/// Returns true if the framebuffer must be resized to (w, h).
pub fn needs_fb(w: u32, h: u32) -> bool {
    let want = ((w as u64) << 32) | h as u64;
    FB.swap(want, Ordering::Relaxed) != want
}

/// Tells the iPhone app what is on screen, so taps map to the right place.
pub fn publish(w: u32, h: u32, offset: u32) {
    #[cfg(target_os = "ios")]
    ramen::platform::ios::set_display(w, h, offset);
    #[cfg(not(target_os = "ios"))]
    let _ = (w, h, offset);
}
