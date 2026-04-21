//! `firmware-r5f` — minimum viable no_std entry point for the AWR2944 MSS
//! (Arm Cortex-R5F). This is intentionally small; it exists to prove that:
//!
//!   1. The Rust toolchain is correctly cross-compiling for armv7r-none-eabihf.
//!   2. The `tlv-parser` crate builds under `#![no_std]` so the same wire
//!      format is enforced on both firmware and host.
//!   3. The memory.x layout links without errors.
//!
//! For a fuller example (exception handlers, MPU setup, L2 caching, FIQ/IRQ
//! vectors), see the WasabiFan/tda4vm-r5f-rust project which targets the
//! closely-related TDA4VM R5F core — link in docs/03-rust-integration.md.
//!
//! The firmware does NOT replace the TI mmW demo; rather, it is a parallel
//! path for teams that want to move incrementally off TI's SysBIOS/FreeRTOS
//! C scaffolding and into Rust as individual modules are rewritten.

#![no_std]
#![no_main]

use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

// Placeholder UART0 address on the AWR2944 MSS — update to match the TRM.
const MSS_UART0_BASE: usize = 0x0204_0000;
const UART_THR:       usize = 0x00;
const UART_LSR:       usize = 0x14;
const UART_LSR_THRE:  u32   = 1 << 5;

// Entry vector. The TI ROM bootloader jumps here after loading the image.
// The name `_start` is the default entry point rust-lld emits for bare-metal
// targets; if you use a custom linker vector table, rename accordingly and
// add it to the `ENTRY(...)` directive of a supplementary link.x.
#[no_mangle]
pub extern "C" fn _start() -> ! {
    // Print a banner once so you can confirm the firmware actually booted
    // over the MSS UART0 data pins.
    for b in b"AWR2944 R5F Rust firmware online.\r\n" {
        uart_putc(*b);
    }

    // Exercise the shared tlv-parser crate: encode a minimal empty frame and
    // parse it back. If this runs without panicking, the no_std parser is
    // correctly linked.
    let mut frame = [0u8; tlv_parser::MAGIC_WORD.len() + tlv_parser::FRAME_HEADER_LEN];
    frame[..tlv_parser::MAGIC_WORD.len()].copy_from_slice(&tlv_parser::MAGIC_WORD);
    // total_packet_len = full frame size
    let tot = frame.len() as u32;
    frame[tlv_parser::MAGIC_WORD.len() + 4..tlv_parser::MAGIC_WORD.len() + 8]
        .copy_from_slice(&tot.to_le_bytes());

    match tlv_parser::FrameParser::parse(&frame) {
        Ok(_) => {
            for b in b"tlv-parser: self-test OK\r\n" {
                uart_putc(*b);
            }
        }
        Err(_) => {
            for b in b"tlv-parser: self-test FAILED\r\n" {
                uart_putc(*b);
            }
        }
    }

    loop {
        cortex_r_wfi();
    }
}

#[inline(always)]
fn uart_putc(c: u8) {
    // Spin until the transmit holding register is empty.
    loop {
        let lsr = unsafe { read_volatile((MSS_UART0_BASE + UART_LSR) as *const u32) };
        if lsr & UART_LSR_THRE != 0 {
            break;
        }
    }
    unsafe {
        write_volatile((MSS_UART0_BASE + UART_THR) as *mut u32, c as u32);
    }
}

#[inline(always)]
fn cortex_r_wfi() {
    // Wait-for-interrupt — parks the core at low power until any IRQ fires.
    unsafe { core::arch::asm!("wfi", options(nomem, nostack)) };
}

#[panic_handler]
fn on_panic(_info: &PanicInfo) -> ! {
    // Bang out a minimal panic notice and halt; a real build should
    // serialize the location through a trace buffer.
    for b in b"!PANIC!\r\n" {
        uart_putc(*b);
    }
    loop {
        cortex_r_wfi();
    }
}
