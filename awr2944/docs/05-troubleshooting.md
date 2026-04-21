# 05 — Troubleshooting

Recipes for the traps we've already fallen into. Check `./scripts/verify-env.sh` output first — it flags most of these automatically.

---

## Install / bootstrap

### `bootstrap-macos.sh` fails at `brew install --cask gcc-arm-embedded`

The cask was renamed at least twice over the years. The script already tries multiple fallbacks; if all three fail, install manually:

```bash
curl -L https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-darwin-arm64-arm-none-eabi.tar.xz -o arm-gnu.tar.xz
sudo mkdir -p /opt/arm-gnu-toolchain
sudo tar -xJf arm-gnu.tar.xz -C /opt/arm-gnu-toolchain --strip-components=1
echo 'export PATH=/opt/arm-gnu-toolchain/bin:$PATH' >> ~/.zshrc
```

(Swap `darwin-arm64` for `darwin-x86_64` on Intel Macs.)

### `docker compose build` on arm64 Linux hangs or says "exec format error"

You're missing the qemu binfmt handlers. Run:

```bash
docker run --privileged --rm tonistiigi/binfmt --install amd64
```

Or re-run `bootstrap-linux-arm64.sh` after Docker is fully up. On the very first boot you may need to log out/in for `docker` group membership.

### `rustup target add armv7r-none-eabihf` says "error: component unavailable"

You're on nightly or an older stable. Switch to the latest stable:

```bash
rustup default stable
rustup update
rustup target add armv7r-none-eabihf
```

If still failing, the target may need to be built from source with `-Z build-std`, which our `firmware-r5f/.cargo/config.toml` already requests.

---

## Serial / USB

### `ls /dev/tty.usbmodem*` shows nothing on macOS even with the EVM plugged in

- Try a different USB-C cable — many are charge-only.
- Look at `system_profiler SPUSBDataType | grep -i xds` to confirm the probe is enumerating at all.
- On Apple Silicon, check you're not blocked by the "Accessory Security" prompt (System Settings → Privacy & Security).

### `/dev/ttyACM*` appears then disappears within a second on Linux

ModemManager is grabbing it. Either mask it:

```bash
sudo systemctl mask ModemManager.service
```

Or reinstall the udev rules (our rules include `TAG+="uaccess"` which modern ModemManager respects):

```bash
sudo ./scripts/bootstrap-linux-arm64.sh
```

### "Permission denied" opening `/dev/ttyACM0`

```bash
sudo usermod -aG dialout $USER
# log out and back in
groups | grep dialout
```

### macOS reports "Device or resource busy" opening the port

Something else is holding it. Candidates: an old `tio` / `screen` session, TI's `dslite.sh`, a terminal emulator. On macOS specifically, CCS and some Apple Silicon kernel extensions fight over CDC-ACM claims — close CCS first, then try again.

---

## Build errors

### `fatal error: 'ti/common/syscommon.h' file not found` building the TI demo

The SDK is not installed (or the container doesn't see it). Run:

```bash
docker compose -f docker/docker-compose.yml run --rm sdk /opt/scripts/install-ti-sdk.sh
```

Then check that `/ti/mmwave_mcuplus_sdk_*` exists inside the container.

### `error: undefined reference to '__aeabi_uidiv'` building the Rust firmware

`opt-level = 0` in the dev profile triggers this on `armv7r-none-eabihf`. The workspace already sets `opt-level = 1` on dev. If you've overridden it, revert — or pull in a `compiler-builtins`-providing crate (e.g. `panic-halt` pulls the right intrinsics).

### `error: rustlib not found for target 'armv7r-none-eabihf'`

You need `rust-src` installed so `build-std` can rebuild libcore:

```bash
rustup component add rust-src
```

### Linker can't find `memory.x`

`memory.x` must be in the crate root, not under `src/`. Our layout places it correctly; the error usually means you're invoking `cargo build` from the workspace root (`rust/`) instead of `rust/firmware-r5f/`. `scripts/build-firmware.sh rust` always `cd`s there first.

---

## Flashing / runtime

### `dslite.sh` fails with "Target connection timed out"

- Check SOP[2:0] is **010** (UART boot) while flashing, not 001.
- Cycle power on the EVM, then retry within 30 seconds.
- If the EVM is connected to a USB hub, try a direct port on the host — some hubs mis-enumerate the composite XDS110 device.

### EVM boots but emits garbage on the control UART

Baud rate or clock mismatch. The TI demo defaults to 115 200 bps on the control port; the R5F is clocked from the XTAL. If you've customised the SysConfig, re-check that the clock tree in `SysConfig` matches the EVM's 40 MHz crystal.

### `host-capture` logs "resync: dropping N bytes" forever

- Wrong port pair — you're reading the *control* port as the data port (or vice-versa). Swap `--control-port` / `--data-port`.
- Wrong data-port baud rate — the demo can be configured at 921 600 or 1 250 000 bps. Pass `--data-baud 1250000` if your `.cfg` requests it.
- Mismatched TLV schema. If you modified the demo's output packet, update `tlv-parser::TlvType` to match.

---

## Platform-specific

### Apple Silicon: UniFlash launches but hangs with a blank window

Rosetta 2 got uninstalled. Reinstall:

```bash
softwareupdate --install-rosetta --agree-to-license
```

### Raspberry Pi 5: Docker build dies with "no space left on device"

The default 32 GB SD / NVMe is tight once qemu has unpacked the full image. Move docker's root to a bigger disk:

```bash
sudo systemctl stop docker
sudo vim /etc/docker/daemon.json
# { "data-root": "/mnt/external/docker" }
sudo systemctl start docker
```

### Linux arm64: `cargo install probe-rs-tools` fails building `hidapi-sys`

Install the `libhidapi-dev` system package first:

```bash
sudo apt install libhidapi-dev libudev-dev
```

---

## When in doubt

1. `./scripts/verify-env.sh` — it will point at the first broken rung.
2. Look at `git diff` / `git status` inside `docker/` — a half-applied tool upgrade is the usual cause of "it worked yesterday".
3. File issues with a paste of `uname -a`, `docker version`, and `rustc -vV`.
