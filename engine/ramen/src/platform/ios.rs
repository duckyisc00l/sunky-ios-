//! SUNKY-IOS: iPhone backend.
//!
//! There are no real windows here. The iPhone app owns the screen; the runner draws into it through
//! EAGL (see gm8emulator's render/opengl/eagl.rs). The app passes input in through the `ramen_ios_*`
//! functions below (from any thread). The runner thread picks it up in `poll_events`.

use crate::{
    error::Error,
    event::Event,
    input::{Key, MouseButton},
    window,
};
use std::sync::{
    atomic::{AtomicBool, AtomicU32, Ordering},
    Mutex,
};

static QUEUE: Mutex<Vec<Event>> = Mutex::new(Vec::new());
/// Drawable size in pixels, set by the app (packed w << 16 | h).
static SCREEN: AtomicU32 = AtomicU32::new((640 << 16) | 480);
/// Size the game asked its window to be (packed w << 16 | h), for the app to read.
static GAME_SIZE: AtomicU32 = AtomicU32::new((640 << 16) | 480);
static CLOSE: AtomicBool = AtomicBool::new(false);

fn push(e: Event) {
    if let Ok(mut q) = QUEUE.lock() {
        q.push(e);
    }
}

/// Windows virtual-key codes (what the app sends) to ramen keys.
fn vk_to_key(vk: u32) -> Option<Key> {
    Some(match vk {
        0x08 => Key::Backspace,
        0x09 => Key::Tab,
        0x0D => Key::Return,
        0x10 => Key::LeftShift,
        0x11 => Key::LeftControl,
        0x12 => Key::LeftAlt,
        0x1B => Key::Escape,
        0x20 => Key::Space,
        0x25 => Key::LeftArrow,
        0x26 => Key::UpArrow,
        0x27 => Key::RightArrow,
        0x28 => Key::DownArrow,
        0x2E => Key::Delete,
        0x30..=0x39 => [
            Key::Alpha0, Key::Alpha1, Key::Alpha2, Key::Alpha3, Key::Alpha4,
            Key::Alpha5, Key::Alpha6, Key::Alpha7, Key::Alpha8, Key::Alpha9,
        ][(vk - 0x30) as usize],
        0x41..=0x5A => [
            Key::A, Key::B, Key::C, Key::D, Key::E, Key::F, Key::G, Key::H, Key::I, Key::J, Key::K, Key::L, Key::M,
            Key::N, Key::O, Key::P, Key::Q, Key::R, Key::S, Key::T, Key::U, Key::V, Key::W, Key::X, Key::Y, Key::Z,
        ][(vk - 0x41) as usize],
        0x70..=0x7B => [
            Key::F1, Key::F2, Key::F3, Key::F4, Key::F5, Key::F6, Key::F7, Key::F8, Key::F9, Key::F10, Key::F11, Key::F12,
        ][(vk - 0x70) as usize],
        _ => return None,
    })
}

/// Key press or release, as a Windows virtual-key code.
#[no_mangle]
pub extern "C" fn ramen_ios_key(vk: u32, down: bool) {
    if let Some(k) = vk_to_key(vk) {
        push(if down { Event::KeyboardDown(k) } else { Event::KeyboardUp(k) });
    }
}

/// Pointer position in drawable pixels.
#[no_mangle]
pub extern "C" fn ramen_ios_mouse_move(x: u32, y: u32) {
    push(Event::MouseMove((x.min(u16::MAX as u32) as u16, y.min(u16::MAX as u32) as u16)));
}

/// Left button (0), right (1) or middle (2).
#[no_mangle]
pub extern "C" fn ramen_ios_mouse_button(button: u32, down: bool) {
    let b = match button {
        1 => MouseButton::Right,
        2 => MouseButton::Middle,
        _ => MouseButton::Left,
    };
    push(if down { Event::MouseDown(b) } else { Event::MouseUp(b) });
}

/// The drawable's size in pixels changed (also call this once before starting a game).
#[no_mangle]
pub extern "C" fn ramen_ios_resize(w: u32, h: u32) {
    let (w, h) = (w.clamp(1, 65535), h.clamp(1, 65535));
    SCREEN.store((w << 16) | h, Ordering::Relaxed);
    push(Event::Resize((w as u16, h as u16)));
}

/// Ask the running game to close (as if its window's close button was pressed).
#[no_mangle]
pub extern "C" fn ramen_ios_request_close() {
    CLOSE.store(true, Ordering::Relaxed);
    push(Event::CloseRequest);
}

/// The size the game wants its window to be, packed as (w << 16) | h.
#[no_mangle]
pub extern "C" fn ramen_ios_game_size() -> u32 {
    GAME_SIZE.load(Ordering::Relaxed)
}

pub(crate) struct Connection;

impl Connection {
    pub(crate) fn new() -> Result<Self, Error> {
        Ok(Connection)
    }
}

pub(crate) struct Window {
    events: Vec<Event>,
}

impl Window {
    pub(crate) fn new(builder: window::Builder) -> Result<Self, Error> {
        let (w, h) = builder.size;
        GAME_SIZE.store(((w as u32) << 16) | h as u32, Ordering::Relaxed);
        CLOSE.store(false, Ordering::Relaxed);
        // Report the real drawable size straight away, so the runner scales to the screen.
        let s = SCREEN.load(Ordering::Relaxed);
        if let Ok(mut q) = QUEUE.lock() {
            q.clear();
            q.push(Event::Resize(((s >> 16) as u16, (s & 0xFFFF) as u16)));
        }
        Ok(Window { events: Vec::new() })
    }

    pub(crate) fn events(&self) -> &[Event] {
        &self.events
    }

    pub(crate) fn poll_events(&mut self) {
        self.events.clear();
        if let Ok(mut q) = QUEUE.lock() {
            std::mem::swap(&mut self.events, &mut *q);
        }
    }

    pub(crate) fn set_maximised(&self, _: bool) {}
    pub(crate) fn set_position(&self, _: (i16, i16)) {}
    pub(crate) fn set_borderless(&self, _: bool) {}
    pub(crate) fn set_resizable(&self, _: bool) {}
    pub(crate) fn set_title(&self, _: &str) {}
    pub(crate) fn set_visible(&self, _: bool) {}

    pub(crate) fn set_size(&self, (w, h): (u16, u16)) {
        GAME_SIZE.store(((w as u32) << 16) | h as u32, Ordering::Relaxed);
        // The screen doesn't change size: tell the runner the real size again.
        let s = SCREEN.load(Ordering::Relaxed);
        push(Event::Resize(((s >> 16) as u16, (s & 0xFFFF) as u16)));
    }
}
