# AWR2944 architecture cheat-sheet

A one-page mental model to orient yourself before writing any firmware.

## Die-level block diagram (simplified)

```
                       ┌──────────────────────────────────────────┐
                       │             AWR2944 SoC                  │
                       │                                          │
   4 TX / 4 RX ╭──▶ ┌──┤  Radio Front-End (76–81 GHz FMCW)        │
   antennas    │    │  │   - PLL, LO synth                         │
   (external)  │    │  │   - IF amp, ADC                           │
               │    │  └──┬───────────────────────────────────────┘
               │    │     │  raw ADC samples (EDMA to L3)
               │    │     ▼
               │    │  ┌───────────────────────────────────────┐
               │    │  │ Hardware Accelerator (HWA)            │
               │    │  │   - FFT, log-mag, CFAR, window        │
               │    │  │   - configured by MSS, results → L3   │
               │    │  └──┬────────────────────────────────────┘
               │    │     │
               │    │     ▼
               │    │  ┌───────────────────────────────────────┐
               │    │  │ Shared L3 RAM (~1 MB)                 │
               │    │  └──┬──────────────────┬─────────────────┘
               │    │     │                  │
               │    │     ▼                  ▼
               │    │  ┌─────────────┐   ┌─────────────────┐
               │    │  │ DSP Sub-    │   │  Main Subsystem │
               │    │  │ System      │   │  (MSS)          │
               │    │  │ (DSS)       │   │                 │
               │    │  │             │   │  Cortex-R5F     │
               │    │  │ C66x DSP    │◀──┼─▶ + L2 RAM 768K │
               │    │  │ + L2 RAM    │   │  + TCMA/B 32K   │
               │    │  │ + corepac   │   │  + CAN-FD, SPI, │
               │    │  │             │   │    QSPI, UART,  │
               │    │  └─────────────┘   │    Ethernet     │
               │    │                    └──┬──────────────┘
               │    │                       │
               ╰────┘                       │ GPIO / CAN / UART
                                            ▼
                                    External microcontroller /
                                    MCUPlus host / ADAS ECU
```

## Core responsibilities

- **MSS (Cortex-R5F)** — application code. Configures the HWA, sets up DMA, programs chirp profiles, owns UART/CAN for off-chip comms. **This is where Rust can run.**
- **DSS (C66x DSP)** — signal processing: range/Doppler FFT stages that don't fit the HWA, tracking algorithms, compression. **No Rust backend — stays in TI C.**
- **HWA** — fixed-function radar datapath. Configured by MSS; cannot be programmed in the sense we usually mean.
- **Radio front-end** — programmed via mailbox commands from the MSS to the on-chip BSS (Bit Slice Sub-system, invisible from software).

## Boot / SOP modes

| SOP[2:0] | Boot source            | When to use                      |
| -------- | ---------------------- | -------------------------------- |
| `000`    | Development / CCS load | Debugging from Code Composer     |
| `001`    | QSPI flash             | **Normal operation after flash** |
| `010`    | UART / serial-boot     | Flashing new firmware            |
| others   | Reserved per device    | See AWR2944 datasheet SWRS265    |

Jumper positions are silkscreened on the EVM next to the `SOP` header.

## Memory map highlights

| Region                | Typical base      | Size      | Used by                       |
| --------------------- | ----------------- | --------- | ----------------------------- |
| QSPI flash (XIP)      | `0x0800_0000`     | 4 MB      | Firmware image                |
| MSS TCMA              | `0x0000_0000`     | 32 KB     | ISR hot paths                 |
| MSS TCMB              | `0x0008_0000`     | 32 KB     | ISR hot paths                 |
| MSS L2 RAM            | `0x1020_0000`     | 768 KB    | R5F application heap/stack    |
| Shared L3 RAM         | `0x8800_0000`     | 1 MB      | HWA ↔ DSS ↔ MSS buffer        |

These values are *representative* — reconcile against the **AWR2944 Technical Reference Manual (SPRUIY8)** before freezing a linker script. Our `rust/firmware-r5f/memory.x` uses this layout with a loud `DO NOT SHIP WITHOUT CHECKING THE TRM` comment.

## Key vocabulary

- **BSS** — Bit Slice Sub-system. The RF front-end's internal controller. You never run code on it directly; you configure it over a mailbox.
- **HWA** — Hardware Accelerator. Fixed-function FFT / CFAR / log-mag pipeline.
- **MSS** — Main Sub-system. The Cortex-R5F application core.
- **DSS** — DSP Sub-system. The C66x.
- **TLV** — Type-Length-Value. Frame encoding used by TI's mmW demo to ship detection results over UART.
- **Magic word** — `02 01 04 03 06 05 08 07`; byte sentinel at the start of every mmW demo frame.
- **CFAR** — Constant-False-Alarm-Rate detector; ubiquitous radar threshold algorithm.
