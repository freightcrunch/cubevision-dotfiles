# 02 — Toolchains and why they're pinned

Three toolchains, one repo. This page explains each, the architecture constraints that dictate which one runs where, and how to obtain the TI installers that can't be automated because they sit behind click-through EULAs.

---

## Toolchain inventory

| Toolchain                 | Targets                    | Runs on                             | Pinned version in this repo  |
| ------------------------- | -------------------------- | ----------------------------------- | ---------------------------- |
| **TI-CGT-ARMLLVM**        | Cortex-R5F (MSS)           | x86_64 Linux / Windows only         | `3.2.2.LTS`                  |
| **TI-CGT-C6000**          | C66x DSP (DSS)             | x86_64 Linux / Windows only         | Bundled with MMWAVE-MCUPLUS-SDK |
| **GNU Arm Embedded (`arm-none-eabi-gcc`)** | Cortex-R5F (MSS) | macOS / Linux x86_64 / Linux arm64 | `13.2.rel1`                  |
| **Rust `armv7r-none-eabihf`** | Cortex-R5F (MSS)       | macOS / Linux x86_64 / Linux arm64 | Stable, rebuilt with `build-std` |
| **MMWAVE-MCUPLUS-SDK**    | —                          | x86_64 Linux host                   | `04.07.00.01` (or current LTS) |
| **SysConfig**             | —                          | x86_64 Linux / macOS                | `1.21.0.3721`                |

TI's compilers and SDK installers are x86_64-Linux-only — which is why the Docker image is pinned to `linux/amd64` even on arm64 hosts, and why the `bootstrap-linux-arm64.sh` script registers `qemu-user-static` binfmt handlers to transparently run x86_64 binaries on arm64 Linux.

The GNU Arm and Rust toolchains, by contrast, *do* have native macOS and arm64 Linux builds — so we install those natively for a fast host-side edit/compile loop on the parts of the codebase that don't require TI's proprietary compiler.

---

## Why both TI-CGT-ARMLLVM *and* GNU Arm Embedded?

- TI-CGT-ARMLLVM is required to build **TI-SDK C code** — the mmW demo, SysBIOS/FreeRTOS glue, and TI's driver packages compile with vendor-specific pragmas, memory attributes, and intrinsics that only TI's fork of Clang understands.
- GNU Arm Embedded is used for:
  1. **Rust linking** — while `rust-lld` can do the link itself, `arm-none-eabi-objcopy` / `objdump` / `size` / `addr2line` come from GNU binutils and plug straight into `cargo-binutils`.
  2. **Greenfield C/C++** — if you write a new MSS module from scratch (no TI SDK dependencies), GNU is fine and portable.
  3. **Host-side firmware analysis** — disassembling `.elf` files, extracting binary images, running `size` to track flash budget.

You do **not** mix them within a single translation unit — the calling conventions are compatible (standard AAPCS), but the vendor-specific `__attribute__((section(".foo")))` extensions and startup files diverge.

---

## Why Rust targets `armv7r-none-eabihf` (not `armv7r-none-eabi`)?

The AWR2944 Cortex-R5F has a VFPv3-D16 FPU. The hard-float ABI target (`armv7r-none-eabihf`) uses FPU registers for argument passing, which matches the ABI TI-CGT-ARMLLVM emits when it generates code with `--target=armv7r-none-eabihf` / `-mfpu=vfpv3-d16`. Using the soft-float `armv7r-none-eabi` target would force all FPU-using code to bounce through integer registers and break interoperability.

Platform support for `armv7r-none-eabi{,hf}` is tier-3 in upstream Rust — there is no prebuilt `libcore`, so our `rust/firmware-r5f/.cargo/config.toml` enables `build-std = ["core", "alloc"]` to rebuild the standard library for the target from source.

---

## Obtaining the TI installers

TI gates the SDK / compiler / SysConfig downloads behind click-through EULAs. We cannot automate the download inside Docker. The workflow is:

1. Create a **free** myTI account: <https://www.ti.com/licreg/docs/swlicexportcontrol.tsp>
2. Download the three Linux x86_64 installers:
   - **MMWAVE-MCUPLUS-SDK** — <https://www.ti.com/tool/MMWAVE-MCUPLUS-SDK> → Get software → "Linux 64-bit installer" (`.run`).
   - **SysConfig** — <https://www.ti.com/tool/SYSCONFIG> → Linux installer (`.run`).
   - **TI-CGT-ARMLLVM** — <https://www.ti.com/tool/download/ARM-CGT-CLANG> → Linux installer (`.bin`).
3. Drop them all into `./installers/` at the top of this repo (directory is gitignored).
4. Inside the Docker container, run:
   ```bash
   docker compose -f docker/docker-compose.yml run --rm sdk /opt/scripts/install-ti-sdk.sh
   ```
   The script silent-installs each one into `/ti` and persists it in the `ti-sdk-cache` Docker volume so future container runs don't re-install.

If you want to work without Docker on an x86_64 Ubuntu host, you can run the same script directly after setting `TI_PREFIX=/opt/ti` in your environment — it doesn't assume containerisation, it just assumes a Linux x86_64 host.

---

## Version pinning policy

We pin every toolchain in two places: `docker/Dockerfile` (as `ARG`s) and `docker/docker-compose.yml` (which forwards them as build args). To upgrade:

1. Change the `ARG` default in `Dockerfile`.
2. Update `docker-compose.yml` to match.
3. Run `docker compose build --no-cache` to rebuild the image.
4. Re-run `./installers/` download for the matching SDK version.
5. Run `./scripts/verify-env.sh` to confirm.

Unpinned upgrades regularly break Makefile defines or linker-script symbols — the most common example is the MMWAVE-MCUPLUS-SDK 04.x → 05.x transition which renamed several demo directories. The whole point of pinning is that you upgrade deliberately.

---

## Sources

- [TI MMWAVE-MCUPLUS-SDK product page](https://www.ti.com/tool/MMWAVE-MCUPLUS-SDK)
- [TI ARM-CGT (download)](https://www.ti.com/tool/ARM-CGT)
- [TI SysConfig](https://www.ti.com/tool/SYSCONFIG)
- [GNU Arm Embedded Toolchain downloads](https://developer.arm.com/downloads/-/gnu-rm)
- [Rust platform support: armv7r-none-eabi{,hf}](https://doc.rust-lang.org/rustc/platform-support/armv7r-none-eabi.html)
