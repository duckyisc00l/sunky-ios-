//! SUNKY-IOS: iPhone backend.
//!
//! The iPhone app runs a RemoteIO audio unit and, from its render callback, calls
//! `udon_ios_render` to fill each buffer. `OutputStream::play` just hands the source over.

use crate::{error::Error, session, source::{self, ChannelCount, SampleRate, Source}};
use std::sync::{atomic::{AtomicU32, Ordering}, Mutex};

static SOURCE: Mutex<Option<Box<dyn Source + Send>>> = Mutex::new(None);
/// Hardware sample rate, set by the app before a game starts.
static RATE: AtomicU32 = AtomicU32::new(48000);

/// Sets the output sample rate (call before starting a game).
#[no_mangle]
pub extern "C" fn udon_ios_set_sample_rate(rate: u32) {
    if rate > 0 {
        RATE.store(rate, Ordering::Relaxed);
    }
}

/// Fills `frames` interleaved stereo f32 frames. Writes silence when nothing is playing.
/// Never blocks for long: if the game thread holds the lock, this buffer is silent.
#[no_mangle]
pub unsafe extern "C" fn udon_ios_render(out: *mut f32, frames: u32) {
    let buf = std::slice::from_raw_parts_mut(out, frames as usize * 2);
    match SOURCE.try_lock() {
        Ok(mut guard) => match guard.as_mut() {
            Some(src) => {
                let n = src.write_samples(buf);
                buf[n.min(buf.len())..].fill(0.0);
            },
            None => buf.fill(0.0),
        },
        Err(_) => buf.fill(0.0),
    }
}

/// Stops whatever is playing (when a game ends).
#[no_mangle]
pub extern "C" fn udon_ios_stop() {
    if let Ok(mut g) = SOURCE.lock() {
        *g = None;
    }
}

pub struct Device;
pub struct OutputStream;
pub struct Session;

impl Device {
    pub fn channel_count(&self) -> ChannelCount {
        source::consts::CH_STEREO
    }

    pub fn sample_rate(&self) -> SampleRate {
        match RATE.load(Ordering::Relaxed) {
            44100 => source::consts::SR_44100,
            _ => source::consts::SR_48000,
        }
    }
}

impl Session {
    pub fn new() -> Result<Self, Error> {
        Ok(Self)
    }

    pub fn default_output_device(&self) -> Result<session::Device, Error> {
        session_wrap!(Ok(Device), Device(DeviceImpl), Ios)
    }

    pub fn open_output_stream(&self, _device: session::Device) -> Result<session::OutputStream, Error> {
        session_wrap!(Ok(OutputStream), OutputStream(OutputStreamImpl), Ios)
    }
}

impl OutputStream {
    pub fn play(&self, source: impl Source + Send + 'static) -> Result<(), Error> {
        if let Ok(mut g) = SOURCE.lock() {
            *g = Some(Box::new(source));
        }
        Ok(())
    }
}
