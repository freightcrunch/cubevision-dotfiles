# 01 — Drivers and debug probe setup

The AWR2944EVM talks to your host over a single USB-C cable that fans out, inside the board, into two separate CDC-ACM interfaces through the on-board **XDS110** debug probe.

Different operating systems expose those interfaces very differently. This page is the reference for what you should see and how to fix it when you don't.

---

## Driver matrix

| Host                            | XDS110 driver             | How serial ports appear                   | JTAG via UniFlash / CCS                        |
| ------------------------------- | ------------------------- | ----------------------------------------- | ---------------------------------------------- |
| macOS 13+ Intel                 | Built-in CDC-ACM          | `/dev/tty.usbmodemR00410261` + `…R00410264` | UniFlash runs natively                         |
| macOS 14+ Apple Silicon         | Built-in CDC-ACM          | Same as Intel                             | UniFlash runs under **Rosetta 2**              |
| Ubuntu 22.04+ x86_64            | Kernel CDC-ACM            | `/dev/ttyACM0` + `/dev/ttyACM1`           | UniFlash runs natively                         |
| Ubuntu 22.04+ arm64             | Kernel CDC-ACM            | Same as x86_64                            | UniFlash x86_64 installer must run in the Docker container (qemu-user-static) |
| Debian 12 arm64                 | Kernel CDC-ACM            | Same as above                             | Same as Ubuntu arm64                           |
| Windows 10/11 x86_64            | TI XDS110 driver pkg      | `COM*` (two ports)                        | Native                                         |
| Windows 11 arm64                | **Not supported**         | n/a                                       | TI driver package won't install on Windows-on-Arm |

The `bootstrap-linux-arm64.sh` script drops `udev/71-ti-xds110.rules` into `/etc/udev/rules.d/` which:

- Sets `MODE=0660` and `GROUP=dialout` on `/dev/ttyACM*` nodes matching the XDS110 VID/PID (`0451:bef3` / `0451:bef4`).
- Tags the raw USB interfaces with `uaccess` so a logged-in desktop user can open them through libusb.
- Creates stable `/dev/ti_xds110_*` symlinks so scripts don't need to guess which of the two `/dev/ttyACM*` nodes is the control vs. data port.

On macOS you don't need udev rules — the kernel enumerates the two CDC-ACM interfaces directly. The downside is that the `/dev/tty.usbmodemR*` suffix changes per probe serial number; identify yours with `ls /dev/tty.usbmodem*` after plugging in.

---

## Which port is which?

Both OSs enumerate the two CDC-ACM interfaces in order. On macOS, the *lower* suffix is the **control** port (115 200 bps), the *higher* is the **data** port (921 600 bps):

```
/dev/tty.usbmodemR00410261   ← control  (you send .cfg lines here)
/dev/tty.usbmodemR00410264   ← data     (TLV frames stream out)
```

On Linux the kernel numbers them in plug order (`/dev/ttyACM0` is usually control, `/dev/ttyACM1` is data), but if you reboot with the EVM already plugged in, the order can flip. The safer approach is to inspect `/dev/serial/by-id/`:

```bash
$ ls -l /dev/serial/by-id/
lrwxrwxrwx 1 root root 13 Apr 20 10:10 usb-Texas_Instruments_XDS110_with_CMSIS-DAP_R00410261-if00 -> ../../ttyACM0
lrwxrwxrwx 1 root root 13 Apr 20 10:10 usb-Texas_Instruments_XDS110_with_CMSIS-DAP_R00410261-if03 -> ../../ttyACM1
```

`if00` is the control port, `if03` is the data port — always, regardless of kernel enumeration.

---

## Verifying the connection

After running the OS-appropriate bootstrap script:

```bash
./scripts/verify-env.sh
```

It will:

- List every `/dev/tty.usbmodem*` (macOS) or `/dev/ttyACM*` (Linux) detected, along with their group/mode.
- Confirm udev rules are installed on Linux.
- Spot-check the Rust workspace parses and the Docker image is built.

A minimal manual test from the CLI:

```bash
# On macOS:
tio /dev/tty.usbmodemR00410261 -b 115200
# On Linux:
tio /dev/ttyACM0 -b 115200
```

Power-cycling the EVM with SOP[2:0] = 001 should print a TI boot banner on the control UART within ~1 second.

---

## Common driver issues

### "Operation not permitted" or "Permission denied" opening `/dev/ttyACM0`

You're not in the `dialout` group. Run `sudo usermod -aG dialout $USER` and log out/in. `verify-env.sh` flags this.

### Two `/dev/ttyACM*` appear and then vanish on Linux

The `ModemManager` daemon is grabbing the XDS110 thinking it's a 3G modem. Our udev rules add `ENV{ID_MM_DEVICE_IGNORE}="1"` by virtue of the `uaccess` tag, but if the problem persists:

```bash
sudo systemctl mask ModemManager.service
```

### UniFlash cannot find the XDS110 on Apple Silicon

The Apple Silicon macOS binary of UniFlash is still Rosetta-only as of UniFlash 8.5. `bootstrap-macos.sh` installs Rosetta 2 automatically. If you skipped that step:

```bash
softwareupdate --install-rosetta --agree-to-license
```

Then re-launch UniFlash. TI have stated Apple-native builds are on the roadmap.

### Linux arm64: `dslite.sh` crashes with "exec format error"

TI's `dslite.sh` is an x86_64 binary. On arm64 Linux, either run it from inside the Docker image (`docker compose run --rm sdk /ti/uniflash_*/dslite.sh …`) or install `qemu-user-static` + `binfmt-support`:

```bash
sudo apt install qemu-user-static binfmt-support
```

After which x86_64 binaries run transparently.

### XDS110 `bef3` vs `bef4`

Early EVMs enumerate as `0451:bef3`; post-rev-B EVMs enumerate as `0451:bef4`. Our udev rules cover both.

---

## Sources

- [TI XDS110 Debug Probe product page](https://software-dl.ti.com/ccs/esd/documents/xdsdebugprobes/emu_xds110.html)
- [TI E2E: Support for XDS110 on arm64?](https://e2e.ti.com/support/tools/code-composer-studio-group/ccs/f/code-composer-studio-forum/1094114/support-for-xds110-on-arm64)
- [Omi AI: Resolving XDS110 driver conflicts on Linux](https://www.omi.me/blogs/firmware-guides/how-to-resolve-driver-conflicts-for-xds110-on-linux-systems)
- [AWR2944EVM product page](https://www.ti.com/tool/AWR2944EVM)
