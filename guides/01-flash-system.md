# 01 — Flash System & Upgrade to SUPER

## Prerequisites

- Host PC running **Ubuntu 22.04 or 24.04** (x86_64, bare metal — VM USB passthrough is unreliable)
- USB-C cable (data-capable, not charge-only)
- DC power adapter connected to the Jetson board
- DP/HDMI cable + monitor (or USB-TTL serial adapter for first-boot debug)
- NVMe SSD installed (recommended over SD card)

## 1. Install SDK Manager (on host PC)

Download from: https://developer.nvidia.com/sdk-manager

```bash
# On host PC
sudo dpkg -i sdkmanager_*_amd64.deb
sdkmanager
```

## 2. Enter Recovery Mode

The reference carrier ships without populated tactile buttons. Use the button header (**J14**, near the DC barrel jack):

1. Power off — unplug the DC barrel completely
2. Wait 10 seconds for caps to drain
3. Short **pins 9 and 10** of J14 (jumper cap, tweezers, or bent paperclip)
4. Connect USB-C to the host
5. Apply DC power while pins 9-10 are still shorted
6. Hold 2-3 seconds after power applies, then remove the jumper
7. Verify on host:

```bash
lsusb | grep -i nvidia
# Should show: NVIDIA Corp. APX (0955:7523)
```

## 3. Flash via SDK Manager

In SDK Manager, select:
- **Product Category**: Jetson
- **Hardware**: Jetson Orin Nano **[8GB developer kit version]** — module P3767-0005, carrier P3768-0000 (bare module variants will not flash correctly)
- **Target OS**: JetPack 7.2.1+ (L4T 39.2.1, Ubuntu 24.04, CUDA 13.2.1, TensorRT 10.16.2)
- **Storage**: NVMe SSD (if available)

Select **Pre-Config** to set username/password/hostname during flash — **do not skip it**.
Without pre-config, first boot runs an OEM wizard that needs console input and blocks network access.

For the first run, **uncheck "Jetson SDK Components"** — flash only the base OS, verify it boots,
then install CUDA/cuDNN/TensorRT components in a second pass.

> **Note**: JetPack 7.2+ has **no SD-card image** for the Orin Nano dev kit — flash via SDK
> Manager or the unified ISO image from a USB stick.

Click **Flash** and wait (~20-30 min).

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

After reboot, check for updates and sync dependencies:

```bash
bash ~/work/CascadeProjects/dotfiles/scripts/update-jetpack.sh --check
bash ~/work/CascadeProjects/dotfiles/scripts/update-jetpack.sh --post
```

## JetPack 6.x → 7.x (Major Upgrade)

There is **no in-place upgrade path** across JetPack majors. JP 7.x moves to
Ubuntu 24.04, kernel 6.8, and CUDA 13.2 — a full reflash is required (steps 1-5 above).

Post-reflash caveats (see NVIDIA forum guide "Orin Nano Super on JetPack 7.2"):
- Prebuilt CUDA 12.6 binaries (dustynv containers, Ollama prebuilt) do **not** work — rebuild from source with `-DCMAKE_CUDA_ARCHITECTURES=87`
- jtop may show "Jetpack NOT DETECTED" — cosmetic; run `scripts/patch-jtop-jetpack.sh`
- Set `MAXN_SUPER` power mode, pin clocks, and grow swap (see guide 13)

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
