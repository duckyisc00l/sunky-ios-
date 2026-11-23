//! SUNKY-IOS: GameMaker's pop-up dialogs (show_message, show_question, get_string, get_integer).
//! OpenGMK left these unimplemented. On iPhone they become real alerts (the app's sunky_dialog,
//! which blocks this thread until the player answers). Elsewhere (the Linux lab) they are logged
//! and answered with the default.

#[cfg(target_os = "ios")]
mod native {
    use std::{ffi::CString, os::raw::c_char};
    extern "C" {
        /// kind: 0 message, 1 yes/no question, 2 text input. Returns 1 for OK/Yes, 0 for No/Cancel.
        /// For text input, the answer is written to `out` (UTF-8, NUL-terminated).
        fn sunky_dialog(kind: i32, text: *const c_char, default: *const c_char, out: *mut c_char, out_len: usize) -> i32;
    }
    pub fn ask(kind: i32, text: &str, default: &str) -> (bool, String) {
        let t = CString::new(text.replace('\0', "")).unwrap_or_default();
        let d = CString::new(default.replace('\0', "")).unwrap_or_default();
        let mut buf = vec![0u8; 1024];
        let ok = unsafe { sunky_dialog(kind, t.as_ptr(), d.as_ptr(), buf.as_mut_ptr().cast(), buf.len()) } != 0;
        let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
        (ok, String::from_utf8_lossy(&buf[..end]).into_owned())
    }
}

#[cfg(not(target_os = "ios"))]
mod native {
    pub fn ask(kind: i32, text: &str, default: &str) -> (bool, String) {
        eprintln!("[dialog {}] {} (answering {:?})", kind, text, default);
        (true, default.to_string())
    }
}

/// GameMaker uses '#' for a new line in messages.
fn gm_text(s: &str) -> String {
    s.replace("\\#", "\u{1}").replace('#', "\n").replace('\u{1}', "#")
}

pub fn message(text: &str) {
    native::ask(0, &gm_text(text), "");
}

pub fn question(text: &str) -> bool {
    native::ask(1, &gm_text(text), "").0
}

pub fn input(prompt: &str, default: &str) -> String {
    let (ok, answer) = native::ask(2, &gm_text(prompt), default);
    if ok { answer } else { default.to_string() }
}
