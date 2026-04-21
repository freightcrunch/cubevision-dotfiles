//! `host-capture` — connects to the AWR2944 EVM's two UARTs, pushes a CLI
//! config to the control port, then streams TLV frames from the data port and
//! decodes them in real time via the shared `tlv-parser` crate.
//!
//! This is deliberately minimal — it's the template you extend when building
//! custom radar post-processing. The important bits are:
//!   * Cross-platform port discovery (works on macOS, Linux x86_64, Linux arm64).
//!   * Ring-buffer reassembly: UART reads don't respect frame boundaries.
//!   * Re-synchronisation by scanning for the magic word on [`ParseError::BadMagic`].
//!
//! Example:
//!   host-capture \
//!       --control-port /dev/tty.usbmodemR00410261 \
//!       --data-port    /dev/tty.usbmodemR00410264 \
//!       --config       configs/awr2944_best_range_resolution.cfg

use std::{
    fs::File,
    io::{BufRead, BufReader, Read, Write},
    path::PathBuf,
    time::Duration,
};

use anyhow::{Context, Result};
use clap::Parser;
use serialport::SerialPort;
use tlv_parser::{FrameParser, MAGIC_WORD, ParseError};
use tracing::{debug, info, warn};

/// Default baud rates used by the TI mmW demo. Override on the CLI if your
/// custom firmware changes them.
const DEFAULT_CONTROL_BAUD: u32 = 115_200;
const DEFAULT_DATA_BAUD:    u32 = 921_600;

/// Size of the ring buffer used for UART reassembly. 64 KiB comfortably holds
/// multiple max-size frames even at the highest demo data rate.
const RING_BUF_LEN: usize = 64 * 1024;

#[derive(Parser, Debug)]
#[command(version, about = "AWR2944 host-side TLV capture + decoder")]
struct Cli {
    /// Path to the *control* UART (the one you push .cfg to).
    #[arg(long)]
    control_port: String,

    /// Path to the *data* UART (the one that emits TLV frames).
    #[arg(long)]
    data_port: String,

    /// mmW demo config file (sent line-by-line to the control port).
    #[arg(long)]
    config: PathBuf,

    /// Baud rate for the control port.
    #[arg(long, default_value_t = DEFAULT_CONTROL_BAUD)]
    control_baud: u32,

    /// Baud rate for the data port.
    #[arg(long, default_value_t = DEFAULT_DATA_BAUD)]
    data_baud: u32,

    /// Stop after this many frames (0 = run forever).
    #[arg(long, default_value_t = 0)]
    max_frames: u64,
}

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();
    let args = Cli::parse();

    // Enumerate serial ports for a friendlier error message when the user
    // mistypes one.
    for p in serialport::available_ports().unwrap_or_default() {
        debug!("found serial port: {}", p.port_name);
    }

    info!("opening control port {} @ {}", args.control_port, args.control_baud);
    let mut control = serialport::new(&args.control_port, args.control_baud)
        .timeout(Duration::from_millis(500))
        .open()
        .with_context(|| format!("failed to open control port {}", args.control_port))?;

    info!("opening data port {} @ {}", args.data_port, args.data_baud);
    let mut data = serialport::new(&args.data_port, args.data_baud)
        .timeout(Duration::from_millis(100))
        .open()
        .with_context(|| format!("failed to open data port {}", args.data_port))?;

    send_config(&mut *control, &args.config)?;

    let mut frames_seen: u64 = 0;
    let mut ring = vec![0u8; 0];
    let mut chunk = [0u8; 4096];

    loop {
        match data.read(&mut chunk) {
            Ok(0) => continue,
            Ok(n) => {
                ring.extend_from_slice(&chunk[..n]);
                if ring.len() > RING_BUF_LEN {
                    // Keep the ring bounded by discarding the oldest bytes.
                    let excess = ring.len() - RING_BUF_LEN;
                    ring.drain(..excess);
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::TimedOut => continue,
            Err(e) => return Err(e).context("data port read failed"),
        }

        // Drain as many whole frames as possible out of the ring.
        loop {
            match FrameParser::parse(&ring) {
                Ok((frame, consumed)) => {
                    handle_frame(&frame);
                    ring.drain(..consumed);
                    frames_seen += 1;
                    if args.max_frames != 0 && frames_seen >= args.max_frames {
                        info!("reached --max-frames {}, exiting", args.max_frames);
                        return Ok(());
                    }
                }
                Err(ParseError::Truncated) => break, // need more bytes
                Err(ParseError::BadMagic) => {
                    // Re-sync: scan forward for the next magic word.
                    if let Some(off) = find_magic(&ring) {
                        warn!("resync: dropping {} bytes of junk before next magic word", off);
                        ring.drain(..off);
                    } else {
                        // No magic word anywhere — drop everything except the
                        // last 7 bytes (they might be the start of a magic).
                        let keep = 7.min(ring.len());
                        let drop = ring.len() - keep;
                        if drop > 0 {
                            ring.drain(..drop);
                        }
                        break;
                    }
                }
                Err(ParseError::TlvOverrun) => {
                    warn!("TLV overrun — header claimed more bytes than the frame contains; dropping frame");
                    // Drop the magic word so we resync on the next one.
                    if !ring.is_empty() {
                        ring.drain(..1);
                    }
                }
            }
        }
    }
}

/// Scan `buf` for the 8-byte mmW magic word.
fn find_magic(buf: &[u8]) -> Option<usize> {
    buf.windows(MAGIC_WORD.len()).position(|w| w == MAGIC_WORD)
}

/// Pretty-prints a frame summary to stdout. Extend this for your workload.
fn handle_frame(frame: &FrameParser<'_>) {
    let h = &frame.header;
    info!(
        frame = h.frame_number,
        detected = h.num_detected_obj,
        tlvs = h.num_tlvs,
        plat = format!("{:#010x}", h.platform),
        cycles = h.time_cpu_cycles,
        "frame"
    );

    for tlv in frame.tlvs() {
        match tlv {
            Ok(t) => debug!(ty = ?t.ty, ty_raw = t.ty_raw, len = t.len, "tlv"),
            Err(e) => {
                warn!("TLV iteration error: {:?}", e);
                break;
            }
        }
    }
}

/// Send a TI mmW `.cfg` file line-by-line to the control port. The demo echoes
/// each line and expects you to wait for "Done"/"Error" before sending the next.
fn send_config(port: &mut dyn SerialPort, path: &std::path::Path) -> Result<()> {
    info!("streaming config {}", path.display());
    let f = File::open(path).with_context(|| format!("opening {}", path.display()))?;
    let reader = BufReader::new(f);

    for line in reader.lines() {
        let mut line = line?;
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('%') {
            continue; // mmW .cfg uses '%' as comment prefix
        }
        line.push_str("\r\n");
        port.write_all(line.as_bytes())?;

        // Give the radar a moment to respond before sending the next line.
        // A more robust impl reads back "Done" or "Error" lines.
        std::thread::sleep(Duration::from_millis(20));
    }
    info!("config streamed");
    Ok(())
}

