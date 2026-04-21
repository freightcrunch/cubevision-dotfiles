# AWR2944 Development Environment

A bootstrapped development environment and Rust-first integration scaffold for the **Texas Instruments AWR2944** 76–81 GHz FMCW automotive radar SoC, targeting **macOS hosts** (Intel and Apple Silicon) and **arm64 Linux dev targets** (Raspberry Pi 5, Jetson, Ampere, etc.).

This repo gives you:

- Bootstrap scripts for both host operating systems, idempotent.
- A pinned, reproducible Docker image containing TI's MMWAVE-MCUPLUS-SDK, the TI-CGT-ARMLLVM compiler, and GNU Arm Embedded — working around the fact that TI's installer is x86_64 Linux only.
- A Cargo workspace with a shared `no_std` TLV parser, a host-side capture tool built on [`serialport`](https://crates.io/crates/serialport), and a skeleton `armv7r-none-eabihf` firmware crate for the Cortex-R5F MSS core.
- udev rules for the XDS110 debug probe and the CP210x USB-to-UART bridge.
- Onboarding documentation for drivers, toolchains, and troubleshooting.

---

## 1. Hardware overview

The AWR2944 is a second-generation automotive radar SoC that packages four heterogeneous compute units on one die:

| Core                | Role                                                                 | Toolchain                     |
| ------------------- | -------------------------------------------------------------------- | ----------------------------- |
| **Arm Cortex-R5F (MSS)** | Main application, control, radar front-end chirp programming     | TI-CGT-ARMLLVM **or** Rust (`armv7r-none-eabihf`) |
| **C66x DSP (DSS)**       | Signal processing kernels (range/doppler/CFAR)                   | TI-C6x CGT (no Rust support)  |
| **Hardware Accelerator (HWA)** | Fixed-function FFT, CFAR, log-mag pipeline                   | Configured via TI SDK APIs    |
| **Radio front-end**      | 4 TX / 4 RX, cascadable                                          | Driven from MSS               |

The **AWR2944EVM** exposes two USB-CDC serial ports through an on-board XDS110 debug probe: a **control UART** (115 200 bps by default — you stream `.cfg` files into it) and a **data UART** (921 600 bps — emits the mmW demo's TLV frame stream). Our Rust host-capture tool speaks both.

---

## 2. Quick start

### macOS host (Intel or Apple Silicon)

```bash
git clone <this-repo> awr2944 && cd awr2944
./scripts/bootstrap-macos.sh
# Launch Docker Desktop once, accept the licence, then:
cd docker && docker compose build && cd ..
# Drop TI installers into ./installers/ (see docs/02-toolchains.md), then:
docker compose -f docker/docker-compose.yml run --rm sdk /opt/scripts/install-ti-sdk.sh
./scripts/verify-env.sh
```

### arm64 Linux dev target

```bash
git clone <this-repo> awr2944 && cd awr2944
./scripts/bootstrap-linux-arm64.sh
# Log out and back in so 'docker' and 'dialout' group membership activates.
cd docker && docker compose build && cd ..
docker compose -f docker/docker-compose.yml run --rm sdk /opt/scripts/install-ti-sdk.sh
./scripts/verify-env.sh
```

The first Docker build on arm64 runs x86_64 emulation under `qemu-user-static`; expect it to take 10–30 minutes depending on host CPU. Subsequent builds are cached.

---

## 3. Repository layout

```
.
├── README.md                          ← this file
├── docs/
│   ├── 01-drivers.md                  ← XDS110 + CP210x driver matrix
│   ├── 02-toolchains.md               ← TI-CGT, ARM GCC, Rust target rationale
│   ├── 03-rust-integration.md         ← Rust host + firmware patterns
│   ├── 04-build-firmware.md           ← Build/flash walkthrough
│   ├── 05-troubleshooting.md          ← Common issues
│   └── architecture.md                ← AWR2944 core architecture cheat-sheet
├── scripts/
│   ├── bootstrap-macos.sh
│   ├── bootstrap-linux-arm64.sh
│   ├── build-firmware.sh              ← dispatches TI or Rust firmware builds
│   ├── flash-uniflash.sh              ← CLI flasher over XDS110
│   └── verify-env.sh                  ← post-install sanity checks
├── docker/
│   ├── Dockerfile                     ← Ubuntu 22.04 + ARM GCC + Rust + TI SDK stubs
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── install-ti-sdk.sh              ← runs inside container, consumes ./installers/
├── udev/
│   └── 71-ti-xds110.rules
├── rust/
│   ├── Cargo.toml                     ← workspace
│   ├── host-capture/                  ← serialport + TLV-decode CLI
│   ├── tlv-parser/                    ← shared no_std wire-format
│   └── firmware-r5f/                  ← no_std Cortex-R5F firmware skeleton
└── installers/                        ← (gitignored) drop TI installers here
```

---

## 4. What the host tools do

| File | Purpose |
| --- | --- |
| `scripts/bootstrap-macos.sh` | Installs Homebrew packages, GNU ARM Embedded, Docker Desktop, Rust + `armv7r-none-eabihf` target, Python venv, Rosetta 2 (Apple Silicon). Idempotent. |
| `scripts/bootstrap-linux-arm64.sh` | Apt-installs toolchains, Docker CE with buildx, registers qemu-user-static for x86_64 emulation, lays down udev rules, installs Rust + target, builds Python venv. |
| `docker/Dockerfile` | Pins **Ubuntu 22.04 x86_64** (TI's validated Linux host target), installs prerequisites, Rust cross-target, and scaffolds TI SDK installation from user-supplied installer blobs. |
| `docker/install-ti-sdk.sh` | Runs inside the container; consumes `./installers/*.run` / `.bin` to silent-install MMWAVE-MCUPLUS-SDK, SysConfig, and TI-CGT-ARMLLVM into `/ti`. |
| `scripts/build-firmware.sh` | Wrapper: `ti mmw_demo` builds the TI C demo inside the container; `rust` builds our Rust R5F firmware natively if the cross-target is present, else falls back to Docker. |
| `scripts/flash-uniflash.sh` | Thin wrapper over TI's `dslite.sh` (UniFlash CLI) — flashes a `.bin` to the EVM over XDS110. |

---

## 5. Building and flashing firmware

```bash
# Build TI's reference mmW demo (C, runs on R5F + C66x):
./scripts/build-firmware.sh ti mmw_demo

# Build the Rust R5F skeleton:
./scripts/build-firmware.sh rust

# Flash to the EVM (EVM must be in SOP[2:0] = 010 flashing mode):
./scripts/flash-uniflash.sh rust/firmware-r5f/target/armv7r-none-eabihf/release/firmware-r5f
```

Full walkthrough with SOP jumper table: see [`docs/04-build-firmware.md`](docs/04-build-firmware.md).

---

## 6. Streaming radar data into Rust

Once the EVM is flashed and booted with SOP[2:0] = 001:

```bash
cd rust
cargo run --release -p host-capture -- \
    --control-port /dev/tty.usbmodemR00410261 \
    --data-port    /dev/tty.usbmodemR00410264 \
    --config       ../configs/awr2944_best_range_resolution.cfg
```

On Linux substitute `/dev/ttyACM0` and `/dev/ttyACM1` (order is arbitrary — the control port is usually the lower-numbered one; check `ls -l /dev/serial/by-id/` to be sure).

The `host-capture` binary implements the re-synchronisation logic every production-grade mmW capture tool needs: UART reads don't respect frame boundaries, so the decoder scans for TI's magic word (`02 01 04 03 06 05 08 07`) on any header mismatch and drops junk bytes until it lands on the next frame.

---

## 7. Why this layout

Four design calls are load-bearing:

1. **Docker for the TI toolchain, native for Rust.** TI's installers ship as x86_64-Linux-only `.run`/`.bin` archives with click-through EULAs. Containerising them isolates the non-portable bits while letting Rust and Python run natively — so `cargo check` on the host still gives you instant feedback when you're iterating on the `tlv-parser` or `host-capture` crates.
2. **Shared `no_std` parser crate.** The `tlv-parser` crate defines the on-wire TLV frame layout *once*, and both the host binary and the R5F firmware consume it. That means you cannot ship a mismatch between the host decoder and the on-device encoder — a class of silent-corruption bug that regularly bites mmW teams using Python + C.
3. **Cargo workspace excludes the firmware crate.** A top-level `cargo build` in the workspace should succeed on the host triple; the firmware crate uses its own `.cargo/config.toml` to pin `armv7r-none-eabihf` and a custom linker script. Excluding it from the workspace prevents Cargo from trying to build it for the host.
4. **Rust focus on the MSS (Cortex-R5F) core only.** There is no mature Rust backend for the C66x DSP. If you need to touch DSS code, you'll write C against the TI-C6x CGT — the Docker image ships that toolchain. We recommend keeping the DSP as a "black box" driven by MSS-side control until the ecosystem improves.

---

## 8. Further reading

- [`docs/architecture.md`](docs/architecture.md) — AWR2944 core architecture cheat-sheet.
- [`docs/01-drivers.md`](docs/01-drivers.md) — XDS110 and USB-UART driver matrix per OS.
- [`docs/02-toolchains.md`](docs/02-toolchains.md) — why we pin each toolchain version.
- [`docs/03-rust-integration.md`](docs/03-rust-integration.md) — deeper Rust patterns (panic handlers, FFI back to TI SDK, `cortex-r` crate status).
- [`docs/04-build-firmware.md`](docs/04-build-firmware.md) — build/flash walkthrough with SOP jumpers.
- [`docs/05-troubleshooting.md`](docs/05-troubleshooting.md) — recipes for the traps we've already fallen into.

---

## 9. Supported host matrix

| Host                              | Status      | Notes                                                     |
| --------------------------------- | ----------- | --------------------------------------------------------- |
| macOS 14+ on Apple Silicon        | Supported   | TI tools run under Docker/Rosetta; Rust+ARM GCC native.   |
| macOS 13+ on Intel                | Supported   | Same path as Apple Silicon, no Rosetta needed.            |
| Ubuntu 22.04 / 24.04 arm64        | Supported   | Docker image runs x86_64 via `qemu-user-static`.          |
| Debian 12 arm64                   | Supported   | Same as Ubuntu arm64.                                     |
| Ubuntu 22.04 x86_64               | Supported   | Fastest path — matches TI's validated host; no emulation. |
| Windows 11 x86_64                 | Not covered | Out of scope for this bootstrap; TI's installer works natively. |
| Windows 11 arm64                  | Unsupported | XDS110 driver does not work on Windows-on-Arm.            |

---

## 10. Licence & attribution

The scripts, Rust crates, and documentation in this repo are MIT / Apache-2.0 dual-licensed. The TI MMWAVE-MCUPLUS-SDK, TI-CGT-ARMLLVM, and SysConfig are redistributed under their respective TI licences; you must accept TI's EULA at download time and cannot redistribute the installers.
