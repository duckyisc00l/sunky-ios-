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
    if win_w == 0 || win_h == 0 {
        return None
    }
    // A room without views is drawn as one view of the whole room, filling the window.
    let (idx, sx, sw, pw) = if !views_enabled {
        (NO_VIEW, 0, room_w, win_w)
    } else {
        let mut visible = views.iter().enumerate().filter(|(_, v)| v.visible);
        let (idx, v) = visible.next()?;
        if visible.next().is_some() {
            return None // split screen
        }
        let angle: f64 = v.angle.into();
        if angle != 0.0 || v.port_x != 0 || v.port_y != 0 || v.port_w != win_w || v.port_h != win_h {
            return None
        }
        (idx, v.source_x, v.source_w, v.port_w)
    };
    if sw <= 0 || pw == 0 {
        return None
    }
    let want_port_w = (win_h as f64 * aspect).round() as i64;
    if want_port_w <= win_w as i64 + 2 {
        return None // already as wide as the screen
    }
    let extra_src = ((want_port_w - win_w as i64) * sw as i64 / pw as i64) as i32;
    let src_w = sw + extra_src;
    let port_w = (src_w as i64 * pw as i64 / sw as i64) as u32;
    // Centre the extra space on the real view; keep it inside the room when the room is wide
    // enough, otherwise it reaches past the room's edges (filled in by cover::extend).
    let mut src_x = sx - (src_w - sw) / 2;
    if src_w <= room_w {
        src_x = src_x.max(0).min(room_w - src_w);
    }
    let offset = ((sx - src_x) as i64 * pw as i64 / sw as i64) as u32;
    Some(Plan { view: idx, src_x, src_w, port_w, offset })
}

/// Plan::view for a room without views.
pub const NO_VIEW: usize = usize::MAX;

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


/// SUNKY-IOS: is something covering the whole view, like a cutscene, a title card or a darkness
/// overlay? Every draw is checked against the real (unwidened) view. A covering draw counts only if
/// little gets drawn on top of it afterwards in the same frame; a backdrop has the level drawn over
/// it. The answer is used for the next frame (one frame late, which can't be seen).
pub mod cover {
    use std::sync::Mutex;

    struct State {
        active: bool,
        base: (f64, f64, f64, f64), // x, y, w, h of the view as drawn (maybe widened), room coordinates
        need: (f64, f64),           // the real view's size: a covering draw fills at least this much
        room_w: f64,
        covered: bool,
        after_area: f64, // view area drawn over the covering draw since it happened
        after_count: u32,
        last: bool,
    }
    static STATE: Mutex<State> =
        Mutex::new(State { active: false, base: (0.0, 0.0, 0.0, 0.0), need: (0.0, 0.0), room_w: 0.0, covered: false, after_area: 0.0, after_count: 0, last: false });

    fn st() -> std::sync::MutexGuard<'static, State> {
        STATE.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// Start watching a frame's draws: the view as it will be drawn, and the real view's size.
    pub fn begin(x: f64, y: f64, w: f64, h: f64, need_w: f64, need_h: f64, room_w: f64) {
        let mut s = st();
        s.room_w = room_w;
        s.active = w > 0.0 && h > 0.0;
        s.base = (x, y, w, h);
        s.need = (need_w, need_h);
        s.covered = false;
        s.after_area = 0.0;
        s.after_count = 0;
    }

    /// Finish the frame: remember whether it ended with the view covered.
    pub fn end() {
        let mut s = st();
        if s.active {
            let (w, h) = s.need;
            s.last = s.covered && s.after_area < 0.25 * w * h && s.after_count < 60;
        } else {
            s.last = false;
        }
        s.active = false;
    }

    /// Whether last frame's view was covered.
    pub fn last() -> bool {
        st().last
    }

    /// A filled axis-aligned rectangle (sprite or shape) was drawn.
    pub fn note(l: f64, t: f64, r: f64, b: f64, alpha: f64) {
        let mut s = st();
        if !s.active || alpha <= 0.02 {
            return
        }
        let (vx, vy, vw, vh) = s.base;
        let (l, r) = if l <= r { (l, r) } else { (r, l) };
        let (t, b) = if t <= b { (t, b) } else { (b, t) };
        let iw = (r.min(vx + vw) - l.max(vx)).max(0.0);
        let ih = (b.min(vy + vh) - t.max(vy)).max(0.0);
        // fills a whole screen's worth of what's drawn (the game may place it by the widened view)
        if iw >= s.need.0 - 4.0 && ih >= s.need.1 - 4.0 {
            s.covered = true;
            s.after_area = 0.0;
            s.after_count = 0;
        } else if s.covered {
            if iw > 0.0 && ih > 0.0 {
                s.after_area += iw * ih;
                s.after_count += 1;
            }
        }
    }

    /// After a draw that fills a whole screen's worth, the strips beside it to fill as well, by
    /// stretching its edges (left strip x1..x2, right strip x1..x2): either side past the room's
    /// edge, or the whole width when last frame was a cutscene, title card or overlay. Keeps the
    /// middle untouched and leaves no level showing beside a cutscene.
    pub fn extend(l: f64, t: f64, r: f64, b: f64) -> (Option<(f64, f64)>, Option<(f64, f64)>) {
        let s = st();
        if !s.active {
            return (None, None)
        }
        let (vx, vy, vw, vh) = s.base;
        let (l, r) = if l <= r { (l, r) } else { (r, l) };
        let (t, b) = if t <= b { (t, b) } else { (b, t) };
        let iw = (r.min(vx + vw) - l.max(vx)).max(0.0);
        let ih = (b.min(vy + vh) - t.max(vy)).max(0.0);
        if iw < s.need.0 - 4.0 || ih < s.need.1 - 4.0 || vw <= s.need.0 + 1.0 {
            return (None, None)
        }
        let overlay = s.last;
        let left = if l > vx + 0.5 {
            let end = if overlay { l } else { l.min(0.0) };
            if end > vx + 0.5 { Some((vx, end)) } else { None }
        } else {
            None
        };
        let right = if r < vx + vw - 0.5 {
            let start = if overlay { r } else { r.max(s.room_w) };
            if start < vx + vw - 0.5 { Some((start, vx + vw)) } else { None }
        } else {
            None
        };
        (left, right)
    }
}
