# 01 — Flash System & Upgrade to SUPER

## Prerequisites

- Host PC running **Ubuntu 22.04 or 20.04** (x86_64)
- USB-C cable (Jetson ↔ Host)
- DC power adapter connected to the Jetson board
- DP/HDMI cable + monitor
- NVMe SSD installed (recommended over SD card)

## 1. Install SDK Manager (on host PC)

Download from: https://developer.nvidia.com/sdk-manager

```bash
# On host PC
sudo dpkg -i sdkmanager_*_amd64.deb
sdkmanager
```

## 2. Enter Recovery Mode

1. Power off the Jetson
2. Hold the **Force Recovery** button (middle button)
3. While holding, press and release the **Power** button
4. Release Force Recovery after 2 seconds
5. Verify on host:

```bash
lsusb | grep -i nvidia
# Should show: NVIDIA Corp. APX
```

## 3. Flash via SDK Manager

In SDK Manager, select:
- **Product Category**: Jetson
- **Hardware**: Jetson Orin Nano Developer Kit
- **Target OS**: JetPack 6.2+ (L4T 36.5)
- **Storage**: NVMe SSD (if available)

Select **Pre-Config** to set username/password during flash.

Click **Flash** and wait (~15 min).

## 4. Flash Directly to NVMe SSD (command line)

If you prefer CLI over SDK Manager:

```bash
# On host PC — download and extract L4T BSP + rootfs
# Then:
sudo ./tools/kernel_flash/l4t_initrd_flash.sh \
    --external-device nvme0n1p1 \
    -c tools/kernel_flash/flash_l4t_t234_nvme.xml \
    -p "-c bootloader/generic/cfg/flash_t234_qspi.xml" \
    --showlogs --network usb0 \
    jetson-orin-nano-devkit-super internal
```

## 5. First Boot

After flashing:
1. Connect DP + keyboard + mouse
2. Power on the Jetson
3. Follow the Ubuntu OOBE (language, timezone, user)
4. Connect to WiFi or Ethernet

```bash
# Verify
cat /etc/nv_tegra_release
sudo apt update && sudo apt upgrade -y
sudo reboot
```

## 6. Upgrade SUB Kit → SUPER

If you have a Yahboom SUB kit (non-SUPER) and want to upgrade:

> Both Jetson Orin Nano and Orin NX use the same flash command for SUPER upgrade.

1. Download the SUPER firmware from Yahboom resources
2. Enter recovery mode (step 2 above)
3. Flash with the SUPER image using the same `l4t_initrd_flash.sh` command

## References

- [Yahboom: Upgrade to SUPER version](https://www.yahboom.net/study/Orin-Nano-SUPER)
- [Yahboom: Official Kit Upgrade Tutorial](https://www.yahboom.net/public/upload/upload-html/1734687172/Official%20Kit%20Upgrade%20Super%20Kit%20Tutorial.html)
- [JetsonHacks: Flash Jetson Orin Nano](https://www.youtube.com/watch?v=q4fGac-nrTI)
