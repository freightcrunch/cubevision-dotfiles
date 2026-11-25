# mmWave Radar — AWR6243 / IWR6243 (57–64 GHz) on Jetson Orin Nano

Host setup for the **TI AWR6243 / IWR6243** 60 GHz FMCW radar front end, plus the legacy
UART path for the D3 DesignCore RS-2944A (AWR2944) further down.

> **Datasheet (direct link):**
> <https://www.ti.com/lit/ds/symlink/iwr6243.pdf?ts=1795627069032> —
> *IWR6243 Single-Chip 57- to 64-GHz FMCW Transceiver*, **SWRS283A**, June 2022, revised
> November 2022. Canonical link: <https://www.ti.com/lit/ds/symlink/iwr6243.pdf>.
> The AWR6243 is the automotive-marketed sibling of the same 57–64 GHz front end; TI
> publishes the device data under the IWR6243 part number, so that datasheet is the
> reference for both. Errata: **SWRZ114** (silicon revision 1.0).

## Read this first: the 6243 is a front end, not a sensor-on-chip

Everything else in this directory was written for an **AWR2944 / IWR6843-class** device:
an on-chip R4F MCU and C674x DSP running TI's mmWave SDK demo, talking to the host over
two USB-UART ports with a CLI and a point-cloud stream. **None of that exists on the
6243.** From the datasheet's device comparison table (Table 6-1):

| Function | IWR6243 | IWR6843 |
|---|---|---|
| MCU (R4F) | **—** | Yes |
| DSP (C674x) | **—** | Yes |
| On-chip memory | **—** | 1.75 MB |
| Hardware accelerator | **—** | Yes |
| CAN-FD / DCAN | **—** | CAN-FD |
| QSPI | development only, **not supported in production** | Yes |
| JTAG | boundary scan only | Yes |
| CSI-2 | **Yes** (4 data + 1 clock lane) | — |
| LVDS | debug only | debug only |
| Cascade (20 GHz sync) | **Yes** | — |
| Max IF | 20 MHz | 10 MHz |
| Max sampling | 45 Msps real / 22.5 Msps complex | 25 / 12.5 Msps |

Consequences for this repo:

- There is **no UART CLI**, no `/dev/radar_cfg`, no CP2105 bridge on the device, and no
  `115200`/`921600` port pair. `99-mmwave-radar.rules` and `setup-mmwave.sh` do not apply.
- There is **no mmWave SDK demo**, no mmWave Demo Visualizer, and no
  `ti_mmwave_rospkg` point cloud: those all need the on-chip DSP/MCU that this part lacks.
- The **host is the radar's processor**. It is the SPI master, it downloads the device
  firmware after every reset, it runs the configuration API sequence, and it receives raw
  ADC samples over MIPI CSI-2 and does all FFT/detection work itself.

## Hardware at a glance

| Item | Detail (datasheet SWRS283A) |
|---|---|
| Device | Single-chip 57–64 GHz FMCW transceiver, 45 nm RFCMOS |
| RF | 7 GHz usable bandwidth, 3 TX / 4 RX, 6-bit TX phase shifter, TX 12 dBm, RX NF 10 dB, phase noise −93 dBc/Hz @ 1 MHz |
| Baseband | Complex (I/Q) architecture, IF high-pass corner configurable above 175 kHz, IF bandwidth to 20 MHz |
| ADC | 45 Msps real / 22.5 Msps complex, with decimation and I/Q correction |
| Control | 4-wire SPI (**device is the SPI peripheral/target**) or I²C, plus `SPI_HOST_INTR_1` for async events |
| Raw data | MIPI D-PHY, CSI-2 v1.1 — 4 data + 1 clock lane, 150–600 Mbps per lane, virtual-channel based, CRC generated |
| Debug data | LVDS (`HS_DEBUG1/2` + the CSI-2 pins) — explicitly **not a production interface** |
| Clock | 40 MHz crystal, or externally driven square/sine; `OSC_CLKOUT` can clock the host |
| Cascade | 20 GHz LO in/out (`FM_CW_SYNCIN1/2`, `FM_CW_SYNCOUT`, `FM_CW_CLKOUT`) + `SYNC_IN`/`SYNC_OUT` frame sync |
| Supplies | 1.2 V digital + SRAM, 1.3 V RF/analog, 1.8 V baseband / VCO / CSI-2, VIO 3.3 V or 1.8 V |
| Package | 161-pin FCBGA, 10.4 × 10.4 mm, 0.65 mm pitch |
| Safety | Developed for IEC 61508, hardware integrity to SIL-2, SIL-2 certified by TÜV SÜD |
| Junction temp | −40 °C to 105 °C |
| Orderables | `IWR6243ABGABL` (tray), `IWR6243ABGABLR` (reel) |

### Board availability

TI does not sell a standalone 6243 BoosterPack-style EVM — on E2E, TI describes the part as
a front end used mainly in **cascaded** designs and points evaluators at a custom board or
a cascade EVM. So the expectation here is a **custom cubevision carrier** (or a cascade
board) with the Jetson as the host, which is why every pin and GPIO in this setup is
configuration, not a hard-coded default. For bench capture, the
[DCA1000EVM](https://www.ti.com/tool/DCA1000EVM) does list IWR6243 among supported sensors
over the LVDS debug port.

## Software you actually need

| Package | Version | What it is |
|---|---|---|
| [**MMWAVE-DFP-2G-60GHZ-FW**](https://www.ti.com/tool/download/MMWAVE-DFP-2G-60GHZ-FW) | **06.04.01.00** (16 Jul 2024) | **The one you need.** Device firmware package for second-generation xWR6243 parts: firmware binaries plus the mmWaveLink reference driver to control, configure, calibrate and monitor the front end. Ships `mmwave_dfp_release_notes.pdf`, the mmWave Radar ICD and `mmwave_dfp_manifest.html`. Export-controlled: a TI login and export approval are required. Windows `.exe` installer and a `.zip`. |
| [mmWave Radar Interface Control Document](https://dr-download.ti.com/software-development/firmware/MD-XRrFQlHOcy/06.04.01.00/mmWave-Radar-Interface-Control.pdf) | shipped with the DFP above | The SPI message protocol: command/response/async-event framing, CRC and ACK behaviour. The radar is always the SPI slave; the external host is the SPI master. |
| [MMWAVE-DFP-2G](https://www.ti.com/tool/MMWAVE-DFP) | 02.02.05.00 (8 Aug 2025) | **Not for the 6243** — AWR2243 (76–81 GHz) only. Easy to grab by mistake. |
| [MMWAVE-SDK](https://www.ti.com/tool/MMWAVE-SDK) / MMWAVE-MCUPLUS-SDK | — | **Not applicable.** These build firmware for the on-chip R4F/DSP, which the 6243 does not have. |
| [RADAR-TOOLBOX](https://www.ti.com/tool/RADAR-TOOLBOX) | 4.00.00.05 | Lists IWR6243 among supported devices; companion examples and post-processing scripts. |
| [MMWAVE-STUDIO](https://www.ti.com/tool/MMWAVE-STUDIO) | 02.01.01.00 / 2G 03.01.04.04 | Windows-only GUI. **No current release lists IWR6243** (1st gen covers xWR1xxx/IWR6843, 2G covers xWR294x/2544/2x44P), so do not plan the bring-up around it; confirm with TI if you want a GUI capture flow. |
| [UniFlash](https://www.ti.com/tool/UNIFLASH) | — | Only relevant to the development-only QSPI flashing mode (SOP `1 0 1`). |

The DFP is export-controlled, so these scripts never download it. Fetch it with a TI
account, then stage it:

```bash
bash mmwave/setup-awr6243.sh --dfp ~/Downloads/mmwave_dfp_06_04_01_00.zip
```

## Quick install

```bash
# Full host setup: packages, spidev, GPIO/udev access, DFP staging, venv, capture path
bash mmwave/setup-awr6243.sh

# Report host readiness without changing anything
bash mmwave/setup-awr6243.sh --check

# Stage the device firmware package
bash mmwave/setup-awr6243.sh --dfp ~/Downloads/mmwave_dfp_06_04_01_00.zip

# Pick the SPI master and prove the host side works (radar unplugged, MOSI->MISO jumper)
bash mmwave/setup-awr6243.sh --spidev /dev/spidev1.0 --selftest

# Prepare the bench capture path instead of CSI-2
bash mmwave/setup-awr6243.sh --capture dca1000
```

Or via the main installer:

```bash
./scripts/install.sh --awr6243
```

What it does:

1. **System packages** — `gpiod`, `libgpiod-dev`, `libftdi1`, `i2c-tools`, `v4l-utils`,
   `usbutils`, `unzip`, `device-tree-compiler`, Python venv tooling.
2. **Host SPI master** — loads `spidev`, makes it boot-persistent in
   `/etc/modules-load.d/awr6243-spidev.conf`, lists `/dev/spidev*`, and on Jetson points
   at `jetson-io` for the 40-pin header pinmux.
3. **Access** — creates/joins the `spi`, `gpio`, `i2c` and `plugdev` groups and installs
   [`99-awr6243.rules`](99-awr6243.rules) for `/dev/spidev*`, `/dev/gpiochip*`,
   `/dev/i2c-*`, FTDI USB-SPI adapters and the XDS110 probe.
4. **Device firmware** — stages the DFP into `~/ti/mmwave_dfp` and finds the firmware
   images (`*metaImage*.bin` / RadarSS + MSS patch binaries).
5. **Carrier config** — creates [`awr6243/board.env`](awr6243/board.env.example) from the
   example, which is where your SPI bus and GPIO offsets live.
6. **Python tooling** — venv at `~/.venvs/radar` with `numpy`, `scipy`, `websockets`,
   `spidev`, `pyftdi` (and your `cubeship-mmwave-firmware/radar/requirements.txt` if present).
7. **Capture path** — checks V4L2 nodes for CSI-2, or prints the DCA1000 networking
   defaults for the LVDS bench path.

## Host wiring

Device pins are from the datasheet signal table (Table 7-1); the host side is whatever your
carrier routes them to, recorded in `awr6243/board.env`.

| Device signal | Pin | Direction | Purpose |
|---|---|---|---|
| `SPI_CS_1` | R7 | in | SPI chip select (default peripheral mode) |
| `SPI_CLK_1` | R9 | in | SPI clock |
| `MOSI_1` | R8 | in | host → radar |
| `MISO_1` | P5 | out | radar → host |
| `SPI_HOST_INTR_1` | P6 | out | async-event interrupt to the host |
| `NRESET` | P12 | in | power-on reset, active low, **hold ≥ 20 µs** |
| `WARM_RESET` | N12 | out | open-drain reset-in-progress status |
| `NERROR_OUT` | N8 | out | open-drain severe-fault indication (recovery is via reset) |
| `NERROR_IN` | P7 | in | fault input from other devices in the system |
| `SOP0 / SOP1 / SOP2` | J13 / P11 / P13 | in | boot mode, sensed at boot (see below) |
| `CSI2_TXP/M[0..3]`, `CSI2_CLKP/M` | G/H/K/L 14-15, J14-15 | out | raw ADC data (also the LVDS debug pins) |
| `SYNC_IN` | N10 | in | low-frequency frame sync; usable as a hardware frame trigger |
| `SYNC_OUT` | P11 | out | frame sync to a secondary device in cascade |
| `OSC_CLKOUT` | A14 | out | cleaned 40 MHz reference for the host or a cascade peer |
| `CLKP` / `CLKM` | E14 / F14 | — | 40 MHz crystal, or external clock on `CLKP` with `CLKM` grounded |

All IOs except `NERROR_IN`, `NERROR_OUT` and `WARM_RESET` are **non-fail-safe** — do not
drive them unless VIO is present.

### Boot modes (SOP straps)

The SOP pins are weakly driven externally and sensed during boot; afterwards the same pins
take on other functions (note `SOP1` shares P11 with `SYNC_OUT`, `SOP0` shares J13 with
`TDO`).

| SOP2 | SOP1 | SOP0 | Mode |
|---|---|---|---|
| 0 | 0 | 1 | **Functional SPI** — normal operation |
| 1 | 0 | 1 | Flashing (development only; QSPI is not a production interface) |
| 0 | 1 | 1 | Debug |
| 1 | 1 | 1 | Functional I²C |

`awr6243/radar-ctl.sh` straps them and pulses reset through libgpiod:

```bash
bash mmwave/awr6243/radar-ctl.sh status        # show line states and the SPI node
bash mmwave/awr6243/radar-ctl.sh boot spi      # hold SOP = 0 0 1, pulse NRESET, keep held
bash mmwave/awr6243/radar-ctl.sh reset         # NRESET pulse only
bash mmwave/awr6243/radar-ctl.sh release       # drop the SOP hold
bash mmwave/awr6243/radar-ctl.sh power on|off  # optional carrier power-enable line
```

`gpioset` releases its lines when it exits, so the script keeps a background holder process
alive for the SOP strap across the reset. If your carrier straps SOP with resistors, skip
the `mode`/`boot` commands and use `reset` alone.

## Bring-up sequence

The device is RAM-based with no production flash path (the datasheet marks QSPI as
development-only), so **the host downloads firmware over SPI after every power-up or
reset**. The order below is the mmWaveLink sequence from the DFP; check the exact API names
and arguments against the `api_guide` and ICD in **your** DFP release, since the host
library is versioned with the firmware.

1. **Power and strap** — bring up the supplies, strap SOP for functional SPI,
   release `NRESET` (≥ 20 µs low).
2. **`rlDevicePowerOn()`** — register the platform callbacks first: `rlComIfCbs_t`
   (SPI open/close/read/write), `rlDeviceCtrlCbs_t` (enable/disable, host IRQ mask, IRQ
   handler registration), `rlOsiCbs_t` (mutex/semaphore/spawn), `rlCrcCbs_t`, timer delay
   and the async-event callback, all inside `rlClientCbs_t` with the host platform set.
   mmWaveLink is OS- and platform-independent and works single-threaded, so a Linux host
   using `spidev` plus a GPIO IRQ is a supported shape.
3. **Wait for the power-up async event** before sending anything else.
4. **Download the firmware** — `rlDeviceFileDownload()` in chunks, from the DFP image
   staged in `AWR6243_FW_IMAGE`.
5. **`rlDeviceGetVersion()`** — confirm the firmware/patch version actually running.
6. **Static configuration** — `rlSetChannelConfig()` (TX/RX enables, cascade device map),
   `rlSetAdcOutConfig()` (sample width, complex/real output), `rlSetLowPowerModeConfig()`.
7. **`rlRfInit()`** — triggers APLL/synthesizer calibration; wait for the calibration-status
   async event.
8. **Data path** — select and configure CSI-2: `rlDeviceSetDataFmtConfig()`,
   `rlDeviceSetDataPathConfig()`, `rlDeviceSetLaneConfig()`, `rlDeviceSetCsi2Config()`,
   plus the HSI clock APIs. Lane mapping matters: samples from different RX channels can be
   multiplexed onto one lane to ease board routing.
9. **Chirp and frame** — `rlSetProfileConfig()`, `rlSetChirpConfig()`, then
   `rlSetFrameConfig()` or `rlSetAdvFrameConfig()`.
10. **`rlSensorStart()`** — wait for the frame-trigger-ready async event; stop with
    `rlSensorStop()`.

Protocol notes from the ICD: it is a stop-and-wait protocol (every message is acknowledged
before the next is sent), SPI words are 16 bits, the ACK timeout is configurable
(`rlDeviceConfigureAckTimeout()`, 0 disables ACK) and CRC is selectable
(`rlDeviceConfigureCrc()`, 16/32/64-bit or none).

## Capturing raw ADC data

The 6243 only ever sends **raw ADC samples** — there is no on-chip detection list. Two
paths, and they are not equivalent:

### CSI-2 into the Jetson (production path)

4 data lanes + 1 clock lane of MIPI D-PHY at 150–600 Mbps per lane. On Tegra this means a
device-tree overlay describing the radar as a 4-lane CSI-2 source and a V4L2 subdev driver
that the NVIDIA capture pipeline (VI/NVCSI) can bind to. **TI publishes no Jetson driver
for this part**, and the device is not a camera — it emits virtual-channel framed ADC data
with its own short/long packet structure, so the driver is bring-up work on our side:

- Check your carrier's CSI connector lane count and routing before committing to a frame
  configuration — chirp + inter-chirp time must be long enough to drain each chirp at the
  configured lane rate.
- Program the data-path APIs (step 8 above) to match the overlay exactly: lane count, lane
  mapping, data rate and sample format.
- NVIDIA's sensor driver programming guide for the Jetson Linux release on the Orin Nano is
  the reference for the overlay and subdev side.

`setup-awr6243.sh --check` reports whether any `/dev/video*` nodes exist and reminds you of
this when none do.

### DCA1000EVM over the LVDS debug port (bench path)

TI's [DCA1000EVM](https://www.ti.com/tool/DCA1000EVM) streams two- and four-lane LVDS
traffic over Ethernet and lists IWR6243 as supported. Useful for antenna and chirp
validation, but LVDS is a debug interface on this device per the datasheet, and the
DCA1000 tooling is Windows-centric. Defaults to confirm in the DCA1000 user guide: FPGA
`192.168.33.180`, host `192.168.33.30`, config UDP 4096, record UDP 4098. The capture must
be started **before** the sensor so the first frame is not missed.

```bash
bash mmwave/setup-awr6243.sh --capture dca1000
sudo ip addr add 192.168.33.30/24 dev <iface>
```

## FTDI USB-SPI on Linux

For bench bring-up without the Jetson in the loop, an FTDI MPSSE adapter (FT232H/FT2232H/
FT4232H) can act as the SPI master via `pyftdi` — the same approach TI's Windows tooling
takes. `99-awr6243.rules` grants `plugdev` access to `0403:6001/6010/6011/6014/6015`. The
kernel's `ftdi_sio` claims the channel as a TTY first, so detach it before use:

```bash
lsusb | grep 0403                      # find the adapter
python -m pyftdi.ftdi list             # enumerate MPSSE interfaces
sudo modprobe -r ftdi_sio              # or unbind just that interface
```

This is a bring-up aid, not the production path: the Jetson's own SPI controller is.

## Verification

```bash
# 1. Host readiness
bash mmwave/setup-awr6243.sh --check

# 2. SPI master exists and works (radar unplugged, MOSI jumpered to MISO)
bash mmwave/setup-awr6243.sh --spidev /dev/spidev1.0 --selftest

# 3. GPIO lines resolve to the right offsets
gpiodetect ; gpioinfo | grep -i -E "spi|gpio"
bash mmwave/awr6243/radar-ctl.sh status

# 4. Firmware staged
ls -la ~/ti/mmwave_dfp
find ~/ti/mmwave_dfp -iname "*metaimage*"

# 5. Strap and reset, then run your host app's power-on + download
bash mmwave/awr6243/radar-ctl.sh boot spi
```

## Troubleshooting

### No `/dev/spidev*` on the Jetson

The 40-pin header pins are muxed to other functions by default:

```bash
sudo /opt/nvidia/jetson-io/jetson-io.py
# Configure 40-pin expansion header -> enable spi1 -> save pin changes -> save and reboot
sudo modprobe spidev
ls -la /dev/spidev*
```

### Permission denied on `/dev/spidev*` or `/dev/gpiochip*`

The udev rules put them in the `spi` and `gpio` groups; group membership needs a fresh
login:

```bash
groups | tr ' ' '\n' | grep -E "spi|gpio|i2c|plugdev"
sudo usermod -aG spi,gpio,i2c,plugdev "$USER"   # then log out and back in
```

### The device never answers on SPI

Work through this in order — on a front-end part, silence is usually power, strap or clock,
not software:

1. **Boot mode** — SOP must read `0 0 1` *while* `NRESET` is released. Check with
   `radar-ctl.sh status` before the reset, not after.
2. **Reset timing** — `NRESET` low for at least 20 µs; the script uses 5 ms.
3. **Supplies and VIO** — 1.2 V digital/SRAM, 1.3 V RF, 1.8 V BB/VCO/CSI-2 and VIO all up
   before any IO is driven; the IOs are non-fail-safe.
4. **Clock** — 40 MHz crystal oscillating, or an external clock on `CLKP` with `CLKM`
   grounded. The clock subsystem has crystal-presence and clock-quality monitors; without a
   good clock nothing boots.
5. **SPI framing** — 16-bit words, correct mode, and chip select actually toggling. Prove
   the host path first with `--selftest`.
6. **`NERROR_OUT`** — if it is asserted, the device hit a severe fault and only a reset
   clears it.

### Firmware download fails or times out

- Download in the chunk size the DFP's example uses; the protocol is stop-and-wait and
  every chunk is acknowledged.
- Check the configured CRC type matches on both sides, and that the ACK timeout is not
  shorter than the device's response time.
- Re-download after **every** reset — there is no persistent image to fall back on.
- Confirm you staged **MMWAVE-DFP-2G-60GHZ-FW** (xWR6243) and not MMWAVE-DFP-2G (AWR2243).

### No async events arrive

`SPI_HOST_INTR_1` (P6) must be routed to a host GPIO with an interrupt, registered through
the mmWaveLink device-control callbacks, and unmasked. Without it the host will send
commands before the device is ready and every response will look like a timeout.

### CSI-2 brings up no frames

Lane count, lane mapping, data rate and sample format must match between the device
configuration APIs and the Tegra device-tree overlay. Also check that the frame timing
leaves enough inter-chirp time to drain each chirp at the configured per-lane rate.

### FTDI adapter is claimed by the kernel

See *FTDI USB-SPI on Linux* above — `ftdi_sio` grabs the interface as a TTY before
`libftdi`/`pyftdi` can open it.

## References

- **IWR6243 datasheet (direct link):** <https://www.ti.com/lit/ds/symlink/iwr6243.pdf?ts=1795627069032>
  — SWRS283A, Rev. A, November 2022
- [IWR6243 product folder](https://www.ti.com/product/IWR6243) — errata SWRZ114, IBIS model SWRM075
- [MMWAVE-DFP-2G-60GHZ-FW 06.04.01.00](https://www.ti.com/tool/download/MMWAVE-DFP-2G-60GHZ-FW) — the xWR6243 device firmware package
- [mmWave Radar Interface Control Document](https://dr-download.ti.com/software-development/firmware/MD-XRrFQlHOcy/06.04.01.00/mmWave-Radar-Interface-Control.pdf) — SPI protocol and message set
- [MMWAVE-DFP tool page](https://www.ti.com/tool/MMWAVE-DFP) — version matrix for the DFP families
- [RADAR-TOOLBOX](https://www.ti.com/tool/RADAR-TOOLBOX) — examples and post-processing
- [DCA1000EVM](https://www.ti.com/tool/DCA1000EVM) — LVDS raw-capture card
- [TI E2E: IWR6243 evaluation board](https://e2e.ti.com/support/sensors-group/sensors/f/sensors-forum/1365975/iwr6243-iwr6243-evaluation-board) — TI on the absence of a standalone 6243 EVM
- [TI E2E: IWR6243 permanent firmware update](https://e2e.ti.com/support/sensors-group/sensors/f/sensors-forum/1499216/iwr6243-permanent-firmware-update) — firmware persistence discussion
- [TI E2E: building the FTDI lib on Linux](https://e2e.ti.com/support/sensors-group/sensors/f/sensors-forum/910711/awr2243-building-ftdi-lib-on-linux) — porting TI's FTDI SPI path off Windows
- [Programming Chirp Parameters (SWRA553)](https://www.ti.com/lit/an/swra553a/swra553a.pdf) — profile/chirp/frame maths

---

# Legacy: RS-2944A (AWR2944) UART path

The original setup in this directory, kept for the D3 DesignCore RS-2944A. It is a
**different device class** from the 6243: an SDK-demo sensor that exposes a CLI and a data
stream over a CP2105 USB-to-UART bridge. Do not run it for a 6243 board.

| Component | Detail |
|---|---|
| Radar | D3 DesignCore RS-2944A (TI AWR2944, 77 GHz) |
| USB bridge | Silicon Labs CP2105 Dual USB-to-UART |
| USB VID:PID | `10c4:ea70` |
| Config port | `/dev/ttyUSB0` → `/dev/radar_cfg` — 115200 baud |
| Data port | `/dev/ttyUSB1` → `/dev/radar_data` — 921600 baud |

```bash
bash mmwave/setup-mmwave.sh              # cp210x, udev rules, dialout, Python venv
bash mmwave/setup-mmwave.sh --check      # check current state only
bash mmwave/setup-mmwave.sh --ros        # ROS Melodic desktop-full + ti_mmwave_rospkg (Docker)
bash mmwave/setup-mmwave.sh --skip-reboot
```

What it installs:

1. **`cp210x` kernel module** — present in JetPack kernels; the script loads it and adds it
   to `/etc/modules-load.d/` for boot persistence.
2. **udev rules** ([`99-mmwave-radar.rules`](99-mmwave-radar.rules)) — stable symlinks
   regardless of USB enumeration order:

   | Symlink | Target | Purpose |
   |---|---|---|
   | `/dev/mmWave_<serial>_00` | config UART | per-serial-number (multi-sensor) |
   | `/dev/mmWave_<serial>_01` | data UART | per-serial-number (multi-sensor) |
   | `/dev/radar_cfg` | config UART | convenience alias (single sensor) |
   | `/dev/radar_data` | data UART | convenience alias (single sensor) |

3. **`dialout` group** membership for serial access without `sudo` (needs a re-login).
4. **Python venv** at `~/.venvs/radar` with `pyserial`, `numpy`, `websockets`, `scipy`.
5. **System packages** — `python3-serial`, `linux-tools-common`, `usbutils`, `minicom`,
   `screen`.
6. **(Optional) ROS Melodic desktop-full + `ti_mmwave_rospkg`** in Docker, since Melodic
   targets Ubuntu 18.04 and cannot be installed natively on 22.04/24.04. The container runs
   `--privileged` with `--device` passthrough for the serial ports.

```bash
# Interactive shell inside ROS Melodic
bash mmwave/ros-melodic-docker/run-ros-melodic.sh

# TI mmWave driver / rviz
bash mmwave/ros-melodic-docker/run-ros-melodic.sh \
    roslaunch ti_mmwave_rospkg 1642es2_short_range.launch
bash mmwave/ros-melodic-docker/run-ros-melodic.sh \
    roslaunch ti_mmwave_rospkg rviz_1642_2d.launch
```

Verification:

```bash
lsmod | grep cp210x
lsusb | grep "10c4"              # 10c4:ea70 Silicon Labs CP2105 Dual UART Bridge
ls -la /dev/radar_* /dev/mmWave_*
screen /dev/radar_cfg 115200     # type: version   (Ctrl+A then K to exit)
```

### Legacy troubleshooting

**No `/dev/ttyUSB*` after connecting**

```bash
lsmod | grep cp210x
sudo modprobe cp210x
sudo dmesg | tail -30 | grep -i "cp210\|usb\|tty"
```

**USB enumeration failure (`device descriptor read/64, error -32`)**

The Jetson sees the physical connection but the CP2105 never completes the USB handshake.
This is electrical, not an aarch64 driver gap (`CONFIG_USB_SERIAL_CP210X=m` is set):

1. Bypass USB hubs — plug straight into the Jetson. VIA Labs hubs (`2109:2822`) and some
   Belkin USB-C adapters break full-speed devices.
2. Try a known-good short data cable (not charge-only).
3. Check the board's power LED — the CP2105 needs good 5 V on VBUS.
4. Reset the USB controller:

   ```bash
   echo "0" | sudo tee /sys/bus/usb/devices/usb1/authorized
   sleep 2
   echo "1" | sudo tee /sys/bus/usb/devices/usb1/authorized
   ```

5. Test the board on another machine to rule out a damaged bridge.
6. Remove any SOP2 flashing jumper — it can hold the bridge in an odd state.

**Permission denied on the serial port**

```bash
groups | grep dialout
sudo usermod -aG dialout "$USER"   # then log out and back in
```

**Sensor not answering CLI commands** — power-cycle it, confirm the flashed SDK firmware
matches the device, and test raw access with `minicom -D /dev/radar_cfg -b 115200`.

### Legacy references

- [TI mmWave Industrial Toolbox — ROS driver](https://dev.ti.com/tirex/explore/node?node=A__AE-D6B.Fk8EFeeiztAQ9rA__com.ti.mmwave_industrial_toolbox__VLyFKFf__LATEST&search=ROS)
- [TI Robotics SDK — radar ROS node setup](https://software-dl.ti.com/jacinto7/esd/robotics-sdk/08_06_01/AM69A/docs/source/docs/radar_driver_node.html)
- [radar-lab/ti_mmwave_rospkg](https://github.com/radar-lab/ti_mmwave_rospkg)
- [D3 DesignCore RS-2944A product page](https://www.d3embedded.com/product/designcore-rs-2944a-mmwave-radar-sensor-evaluation-kit/)
- [TI mmWave Demo Visualizer](https://dev.ti.com/gallery/view/mmwave/mmWave_Demo_Visualizer/)
