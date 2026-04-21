# 03 — Rust integration patterns

A field guide to the three places Rust shows up in this repo, plus the roadmap for rewriting more of the stack in Rust as the ecosystem matures.

---

## Where Rust fits today

| Layer                                     | Language today | Rust status                                                           |
| ----------------------------------------- | -------------- | --------------------------------------------------------------------- |
| **Host-side capture + analytics**         | Rust + Python  | `rust/host-capture/` — production-ready pattern.                      |
| **Shared on-wire TLV frame schema**       | Rust (`no_std`) | `rust/tlv-parser/` — single source of truth, used by both sides.      |
| **R5F (MSS) application logic**           | C (TI SDK)     | Partial via `rust/firmware-r5f/`. Rewrite incrementally.              |
| **R5F low-level drivers (CAN, EDMA, HWA)**| C (TI SDK)     | Stay in TI C for now; call out to them via FFI from Rust.             |
| **C66x DSP (DSS)**                        | C (TI C6x CGT) | Not feasible in Rust — no backend for C6x exists.                     |
| **BSS (RF front-end firmware)**           | TI proprietary | Black box — never user-written.                                       |

The practical consequence: **don't rewrite the DSP in Rust, and don't fight the SDK for drivers.** Instead, use Rust where it offers the biggest correctness/safety win — host-side decode, state machines, configuration, and the on-wire contract — and leave the deeply vendor-entangled pieces in TI's C.

---

## Host crate: `rust/host-capture`

A self-contained CLI that:

1. Opens the two UARTs exposed by the XDS110 (`serialport` crate, which is cross-platform — same binary works on macOS, Linux arm64, Linux x86_64).
2. Streams a TI `.cfg` file line-by-line to the control port (`send_config`).
3. Reads chunks from the data port into a bounded ring buffer.
4. Drains whole TLV frames out of the ring via the shared `tlv-parser` crate.
5. Implements **re-sync by magic-word scan** when the stream gets out of step — the single most common bug in hand-rolled mmW decoders.

Extension points:

- Enable the optional `json` feature (`cargo run --features json ...`) to serialize every frame for downstream tools.
- Replace `handle_frame` with a real sink: parquet writer, `nng` socket, UDP multicast, etc.
- Swap the ring buffer for `tokio` channels if you need multi-consumer fan-out.

---

## Shared crate: `rust/tlv-parser`

`#![no_std]`. Enforces the on-wire TLV frame layout from TI's mmW demo, plus a re-sync helper. Both `host-capture` and `firmware-r5f` depend on it, so any layout drift shows up as a build failure rather than as silent corruption on the data port.

Design decisions:

- **Zero-copy parsing** — `FrameParser` borrows a `&[u8]`; no heap allocation even on the host.
- **Unknown TLV types fold to a sentinel** (`TlvType::Unknown`) rather than erroring. The demo defines custom types per-application; you still want to walk past them.
- **Re-sync is the caller's job.** `parse()` returns `BadMagic` when the head of the buffer isn't a frame boundary; the caller scans forward for the magic word. That keeps the parser pure and re-entrant.
- **Deliberately small.** Tests live alongside the code. No bindgen, no derive macros — this is a schema, not a platform.

---

## Firmware crate: `rust/firmware-r5f`

Minimum viable bare-metal Rust binary for the AWR2944 MSS Cortex-R5F.

### Target triple

```
armv7r-none-eabihf
```

VFPv3-D16 hard-float ABI, matches TI-CGT-ARMLLVM's default calling convention on the R5F. See [`02-toolchains.md`](02-toolchains.md) for the rationale.

### Notable config choices

- `panic = "abort"` on both dev and release — unwinding is not meaningful on a bare-metal radar controller.
- `build-std = ["core", "alloc"]` — `armv7r-none-eabihf` is a tier-3 target with no prebuilt `libcore`, so we rebuild it from source per-release.
- `opt-level = 1` on dev — `opt-level = 0` generates too many calls to intrinsics like `__udivsi3` that aren't linked by default.
- Custom linker scripts: `memory.x` defines the MSS memory map; `link.x` (pulled in via rustflags) is rust-embedded's standard cortex-m-rt-style startup — when we graduate from the placeholder `_start` to a full exception vector table we'll bring in `aarch32-rt` properly.

### Using the TI SDK from Rust

You have three options for calling TI's C driver stack from Rust, in order of increasing effort and increasing control:

1. **Shell out**: have Rust firmware handle just the parts you own; TI's C code handles the rest. Link the two into one image via TI-CGT-ARMLLVM as the final linker. Call convention is plain AAPCS so it works, but the build graph is awkward.

2. **`bindgen` on TI headers**: use `bindgen` from a `build.rs` to auto-generate `extern "C"` FFI signatures for `mmwavelink/`, `mmwave_utils/`, etc. Pragmatic for moderate-sized integrations; you get the ugly but correct types. Downside: TI's headers include a mountain of macros that don't translate, so you curate which headers you run bindgen against.

3. **Hand-roll FFI**: write small `extern "C"` blocks declaring only the functions you call. Fastest incremental path, most maintenance.

We recommend option 3 for the first year of any AWR2944-on-Rust adoption: write a thin Rust "platform" module that imports the ~20 SDK functions you actually use, and keep everything else in TI's C until the Rust-side design settles.

### Reference: WasabiFan's `tda4vm-r5f-rust`

The TDA4VM uses the same Cortex-R5F core as the AWR2944 MSS. [WasabiFan/tda4vm-r5f-rust](https://github.com/WasabiFan/tda4vm-r5f-rust) has worked examples of:

- FPU context save/restore on IRQ entry
- MPU region setup from Rust
- L1/L2 cache enable
- Vector-table layout compatible with TI's `SBL` (Secondary BootLoader)

Lift patterns from that repo as you extend `firmware-r5f/src/main.rs` beyond the current "print banner + parse test" skeleton.

---

## Worked integration patterns

### Pattern A — Rust host tool drives a pre-built TI demo

- Flash TI's pre-built `xwr29xx_mmw_demo.bin`.
- Run `host-capture` — it streams your `.cfg` and decodes frames.
- All radar signal processing is still inside TI's demo.

This is the **fastest path to a working pipeline**, and the one you start with on day one.

### Pattern B — Rust host + modified TI demo

- Fork TI's demo (inside `/ti/mmwave_mcuplus_sdk_*/ti/demo/awr2944/mmw_demo/` in the container) and tweak the DSP chain.
- Continue to decode on the host via `tlv-parser`.
- If you add a new TLV type, update `TlvType` in `tlv-parser/src/lib.rs` first, then the demo's `mmw_output.c`. A CI job could diff the two files.

### Pattern C — Rust host + Rust-in-MSS, TI-C-in-DSS

- The MSS runs `firmware-r5f` (or a hybrid image where Rust owns the main loop and FFI calls into TI's SDK for drivers).
- The DSS continues to run TI's C signal chain, loaded and kicked by the MSS.
- This is the full vision — incremental migration from TI's C into Rust on the application core, while leaving the DSP alone.

### Pattern D — Python adjunct for offline analysis

Python isn't going anywhere: `pymmw`, `pyRadar`, and TI's reference plotters are all Python. The pattern we recommend: `host-capture` writes frames to disk (NDJSON with `--features json`, or a parquet file via an extension), Python loads them after the capture is done. This avoids the common trap of Python trying to keep up with a 921 600-bps UART in real time.

---

## Sources

- [`serialport` crate](https://crates.io/crates/serialport)
- [`serial2` crate (alternative)](https://github.com/de-vri-es/serial2-rs)
- [`WasabiFan/tda4vm-r5f-rust`](https://github.com/WasabiFan/tda4vm-r5f-rust) — Rust firmware on the closely-related TDA4VM Cortex-R5F.
- [Rust Embedded FAQ](https://docs.rust-embedded.org/faq.html)
- [The Embedonomicon](https://docs.rust-embedded.org/embedonomicon/) — what to know when writing a bare-metal Rust runtime from scratch.
- [`pymmw`](https://github.com/m6c7l/pymmw) — reference for TLV parsing patterns in Python.
- [`pyRadar`](https://github.com/gaoweifan/pyRadar) — raw ADC + UART capture for TI sensors, including AWR2243.
