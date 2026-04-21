# 04 — Building and flashing firmware

End-to-end walkthrough: from source to a booting AWR2944EVM.

---

## Option 1 — TI reference mmW demo (C)

The fastest sanity check. You end up with a functionally-complete radar that `host-capture` can decode.

```bash
# One-time: install the TI SDK inside the container.
docker compose -f docker/docker-compose.yml run --rm sdk /opt/scripts/install-ti-sdk.sh

# Build:
./scripts/build-firmware.sh ti mmw_demo
```

Under the hood, `build-firmware.sh` runs, inside the container:

```
cd /ti/mmwave_mcuplus_sdk_<ver>/ti/demo/awr2944/mmw_demo
make clean && make all
```

Artefacts land in the demo directory — look for `.xer5f` (R5F ELF), `.xe66` (C66x ELF), and `.bin` (flash image). The build grabs TI-CGT-ARMLLVM for the R5F build and the C66x CGT for the DSP side, merges them, and emits a bootable QSPI image.

## Option 2 — Rust `firmware-r5f`

A minimal no_std skeleton for when you want to own the MSS boot path from Rust.

```bash
./scripts/build-firmware.sh rust
```

This runs, in `rust/firmware-r5f/`:

```
cargo build --release
```

Output ELF: `rust/firmware-r5f/target/armv7r-none-eabihf/release/firmware-r5f`.

Convert to a raw binary before flashing:

```bash
arm-none-eabi-objcopy -O binary \
  rust/firmware-r5f/target/armv7r-none-eabihf/release/firmware-r5f \
  firmware-r5f.bin
```

## Flashing

The EVM boots from QSPI when SOP[2:0] = 001 and listens for new firmware over UART / XDS110 when SOP[2:0] = 010.

### SOP jumper table

| Mode          | SOP2 | SOP1 | SOP0 | When to use                            |
| ------------- | ---- | ---- | ---- | -------------------------------------- |
| Development   | OFF  | OFF  | OFF  | CCS / JTAG load only, no flash boot.   |
| Flash boot    | OFF  | OFF  | ON   | **Normal operation — EVM runs its flashed firmware.** |
| UART boot     | OFF  | ON   | OFF  | **Flashing a new image over XDS110 or USB-UART.** |

(OFF = jumper removed, ON = jumper installed. Silkscreen on the EVM shows `0` / `1` matching this table.)

### Flash procedure

1. Power off the EVM.
2. Move SOP jumpers to the **UART boot** position (SOP[2:0] = 010).
3. Connect USB. Both `/dev/ttyACM*` (or `/dev/tty.usbmodem*`) devices appear.
4. Run:
   ```bash
   ./scripts/flash-uniflash.sh path/to/firmware.bin
   ```
   Which calls TI's `dslite.sh` with the AWR2944 XDS110 `.ccxml` target config.
5. On success, power off. Move SOP back to **flash boot** (SOP[2:0] = 001). Power on.

On arm64 Linux, `dslite.sh` is an x86_64 binary — run it through qemu (automatic if `qemu-user-static` is installed) or from inside the Docker container:

```bash
docker compose -f docker/docker-compose.yml run --rm sdk \
  /ti/uniflash_*/dslite.sh --mode flash \
  -c /ti/uniflash_*/user_files/configs/AWR2944_XDS110_USB.ccxml \
  -f /workspace/firmware-r5f.bin
```

Pass `--devices` through to docker compose to forward `/dev/ttyACM*`.

## Validating the boot

Open the control UART at 115 200 bps:

```bash
tio /dev/tty.usbmodemR00410261 -b 115200           # macOS
tio /dev/ttyACM0 -b 115200                         # Linux
```

You should see a TI SBL banner within a second of power-up, followed by the application's own prints:

- **TI mmW demo**: prints `mmwave_mcuplus_sdk_<ver>` and a prompt.
- **Our Rust skeleton**: prints `AWR2944 R5F Rust firmware online.` followed by `tlv-parser: self-test OK`.

Nothing? See [`05-troubleshooting.md`](05-troubleshooting.md).
