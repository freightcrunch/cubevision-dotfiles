# mmWave Radar — RS-2944A Driver Setup for Jetson Orin Nano

Install and configure the **D3 DesignCore RS-2944A** (AWR2944) 77 GHz mmWave radar sensor
on an NVIDIA Jetson Orin Nano running JetPack 6 / Ubuntu 22.04 (aarch64).

## Hardware

| Component | Detail |
|-----------|--------|
| **Radar** | D3 DesignCore RS-2944A (TI AWR2944, 77 GHz) |
| **USB bridge** | Silicon Labs CP2105 Dual USB-to-UART |
| **USB VID:PID** | `10c4:ea70` |
| **Config port** | `/dev/ttyUSB0` → `/dev/radar_cfg` — 115200 baud |
| **Data port** | `/dev/ttyUSB1` → `/dev/radar_data` — 921600 baud |

## Quick Install

```bash
# Full automated setup
bash mmwave/setup-mmwave.sh

# Or step-by-step with options
bash mmwave/setup-mmwave.sh --check       # check current state only
bash mmwave/setup-mmwave.sh --ros         # also install ROS Melodic desktop-full (Docker)
bash mmwave/setup-mmwave.sh --skip-reboot # skip reboot prompt at end
```

Or via the main installer:

```bash
./scripts/install.sh --mmwave
```

## What Gets Installed

### 1. Kernel Module — `cp210x`

The CP2105 USB-to-UART bridge on the RS-2944A requires the `cp210x` kernel module.
JetPack 6 (kernel 5.15-tegra) **includes this module by default**. The setup script
verifies it's loaded and adds it to `/etc/modules-load.d/` for boot persistence.

### 2. udev Rules — `99-mmwave-radar.rules`

Creates stable device symlinks regardless of USB enumeration order:

| Symlink | Target | Purpose |
|---------|--------|---------|
| `/dev/mmWave_<serial>_00` | Config UART | Per-serial-number (multi-sensor) |
| `/dev/mmWave_<serial>_01` | Data UART | Per-serial-number (multi-sensor) |
| `/dev/radar_cfg` | Config UART | Convenience alias (single sensor) |
| `/dev/radar_data` | Data UART | Convenience alias (single sensor) |

### 3. User Permissions — `dialout` Group

Adds the current user to the `dialout` group so serial ports can be accessed
without `sudo`. Requires logout/login to take effect.

### 4. Python Dependencies

Installs `pyserial`, `numpy`, `websockets`, and `scipy` in a virtual environment
at `~/.venvs/radar` (or a path you specify) for the radar serial parser and
WebSocket bridge in `cubeship-mmwave-firmware/radar/`.

### 5. System Packages

```
python3-serial  linux-tools-common  usbutils  minicom  screen
```

### 6. (Optional) ROS Melodic desktop-full + TI mmWave ROS Driver (Docker)

ROS Melodic targets Ubuntu 18.04 (Bionic) and **cannot be installed natively** on
Ubuntu 22.04. With `--ros`, the script builds a Docker image containing:

- `ros-melodic-desktop-full` (rviz, rqt, PCL, OpenCV, etc.)
- `ti_mmwave_rospkg` driver ([radar-lab/ti_mmwave_rospkg](https://github.com/radar-lab/ti_mmwave_rospkg))
- `serial` ROS library dependency ([wjwwood/serial](https://github.com/wjwwood/serial))
- Pre-built catkin workspace at `/catkin_ws`

The container runs with `--privileged` and `--device` passthrough so it can
access `/dev/ttyUSB*` and `/dev/radar_*` serial ports directly.

```bash
# Build the image (one-time, ~10-20 min)
bash mmwave/setup-mmwave.sh --ros

# Interactive shell inside ROS Melodic
bash mmwave/ros-melodic-docker/run-ros-melodic.sh

# Launch the TI mmWave driver directly
bash mmwave/ros-melodic-docker/run-ros-melodic.sh \
    roslaunch ti_mmwave_rospkg 1642es2_short_range.launch

# Launch with rviz visualizer (needs X11)
bash mmwave/ros-melodic-docker/run-ros-melodic.sh \
    roslaunch ti_mmwave_rospkg rviz_1642_2d.launch
```

Inside the container, radar topics are available at:
```bash
rostopic list
rostopic echo /ti_mmwave/radar_scan
```

## Verification

After install and reboot/re-login:

```bash
# 1. Check kernel module
lsmod | grep cp210x

# 2. Connect the RS-2944A via USB, then:
lsusb | grep "10c4"
# Bus 001 Device 003: ID 10c4:ea70 Silicon Labs CP2105 Dual UART Bridge

# 3. Check symlinks
ls -la /dev/radar_* /dev/mmWave_*
# /dev/radar_cfg  -> ttyUSB0
# /dev/radar_data -> ttyUSB1

# 4. Quick serial test (press Ctrl+A then K to exit)
screen /dev/radar_cfg 115200
# Type: version
# Should respond with AWR2944 firmware version

# 5. Run the radar bridge
cd ~/work/cubeship-mmwave-firmware/radar
source ~/.venvs/radar/bin/activate
python radar_bridge.py --config-port /dev/radar_cfg --data-port /dev/radar_data
```

## Troubleshooting

### No `/dev/ttyUSB*` after connecting

```bash
# Check if cp210x is loaded
lsmod | grep cp210x

# If not, load manually
sudo modprobe cp210x

# Check dmesg for USB errors
sudo dmesg | tail -30 | grep -i "cp210\|usb\|tty"
```

### USB enumeration failure (`device descriptor read/64, error -32`)

If `dmesg` shows repeated errors like:

```
usb 1-2.2: device descriptor read/64, error -32
usb 1-2.2: Device not responding to setup address
usb 1-2.2: device not accepting address 109, error -71
usb 1-2-port2: unable to enumerate USB device
```

This means the Jetson USB controller **detects the physical connection** but the
CP2105 bridge chip never responds to the initial USB handshake. This is a
hardware/electrical issue, **not** an ARM/aarch64 driver problem — the `cp210x`
module exists and is correct (`CONFIG_USB_SERIAL_CP210X=m`).

**Try these steps in order:**

1. **Bypass USB hubs** — Connect the RS-2944A directly to the Jetson Orin Nano's
   USB-A or USB-C port. VIA Labs hubs (`2109:2822`) and Belkin USB-C adapters
   are known to cause enumeration failures with some full-speed USB devices.

   ```bash
   # Unplug from hub, plug directly into Jetson USB port, then:
   sudo dmesg -w   # watch live for enumeration
   lsusb | grep "10c4"
   ```

2. **Try a different USB cable** — Some cables are charge-only (no data lines) or
   have degraded shielding. Use a known-good data cable, ideally short (< 1m).

3. **Check RS-2944A board power** — Verify the radar board's power LED is on and
   stable. The CP2105 USB bridge needs 5V from VBUS; if the board's power
   regulator is not providing proper voltage, the CP2105 may not initialize.

4. **Reset the USB controller** — Force the Jetson to re-enumerate all devices:

   ```bash
   # Unplug the RS-2944A, then:
   echo "0" | sudo tee /sys/bus/usb/devices/usb1/authorized
   sleep 2
   echo "1" | sudo tee /sys/bus/usb/devices/usb1/authorized
   # Re-plug the RS-2944A
   ```

5. **Test on another machine** — To rule out a defective CP2105, try connecting
   the RS-2944A to a laptop or x86 desktop. If it also fails there, the board's
   USB bridge may be damaged.

6. **Check SOP jumper state** — If the RS-2944A has an SOP2 jumper set for
   flashing mode, the radar MCU may hold the CP2105 in an unusual state.
   Remove SOP2 for normal operation.

### Permission denied on serial port

```bash
# Verify group membership
groups | grep dialout

# If not present, add and re-login
sudo usermod -aG dialout $USER
# Then logout and login again
```

### Device shows as wrong `/dev/ttyUSBx` number

The udev rules create stable symlinks (`/dev/radar_cfg`, `/dev/radar_data`)
that point to the correct device regardless of USB enumeration order.
Always use the symlinks instead of raw `ttyUSBx` paths.

### Sensor not responding to CLI commands

1. Power-cycle the RS-2944A (unplug USB, wait 3s, replug)
2. Ensure the correct firmware is flashed (TI mmWave SDK compatible with AWR2944)
3. Use `minicom -D /dev/radar_cfg -b 115200` to test raw CLI access

## References

- [TI mmWave Industrial Toolbox — ROS Driver](https://dev.ti.com/tirex/explore/node?node=A__AE-D6B.Fk8EFeeiztAQ9rA__com.ti.mmwave_industrial_toolbox__VLyFKFf__LATEST&search=ROS)
- [TI Robotics SDK — Radar ROS Node Setup](https://software-dl.ti.com/jacinto7/esd/robotics-sdk/08_06_01/AM69A/docs/source/docs/radar_driver_node.html)
- [radar-lab/ti_mmwave_rospkg — ROS Melodic Driver](https://github.com/radar-lab/ti_mmwave_rospkg)
- [TI mmWave ROS Driver Setup Guide (PDF)](https://usermanual.wiki/Document/TImmWaveROSDriverSetupGuide.1906397350/help)
- [D3 DesignCore RS-2944A Product Page](https://www.d3embedded.com/product/designcore-rs-2944a-mmwave-radar-sensor-evaluation-kit/)
- [TI mmWave Demo Visualizer](https://dev.ti.com/gallery/view/mmwave/mmWave_Demo_Visualizer/)
- [Programming Chirp Parameters (TI App Note)](https://www.ti.com/lit/an/swra553a/swra553a.pdf)
