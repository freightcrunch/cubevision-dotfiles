# 13 — Performance Tuning

## 1. Power Modes

The Orin Nano SUPER has multiple power modes:

```bash
# List available modes
sudo nvpmodel -q --verbose

# Current mode
sudo nvpmodel -q

# Set to MAX performance (15W, all cores, max clocks)
sudo nvpmodel -m 0

# Set to power-saving (7W)
sudo nvpmodel -m 1
```

| Mode | Power | Description |
|------|-------|-------------|
| 0 | 15W | MAXN — max performance |
| 1 | 7W | Power saving |

## 2. Jetson Clocks

Lock CPU, GPU, and EMC at maximum frequency:

```bash
# Enable max clocks
sudo jetson_clocks

# Check status
sudo jetson_clocks --show

# Restore default (dynamic scaling)
sudo jetson_clocks --restore
```

## 3. Fan Control

```bash
# Max fan speed
sudo jetson_clocks --fan

# Manual fan control
sudo sh -c 'echo 255 > /sys/devices/pwm-fan/target_pwm'

# Check current fan speed
cat /sys/devices/pwm-fan/cur_pwm
```

## 4. Memory Optimization

### Disable Desktop (headless mode)

```bash
# Switch to multi-user (no GUI)
sudo systemctl set-default multi-user.target
sudo reboot

# Re-enable desktop
sudo systemctl set-default graphical.target
sudo reboot
```

Saves ~500 MB RAM.

### Increase Swap

```bash
# Check current swap
free -h

# Create 8 GB swap file
sudo fallocate -l 8G /mnt/swapfile
sudo chmod 600 /mnt/swapfile
sudo mkswap /mnt/swapfile
sudo swapon /mnt/swapfile

# Make permanent
echo '/mnt/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Disable zram (if using SSD swap)

```bash
sudo systemctl disable nvzramconfig
sudo reboot
```

## 5. CPU Governor

```bash
# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set to performance (max freq)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee $gov
done

# Set to schedutil (balanced, default)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo schedutil | sudo tee $gov
done
```

## 6. OMP / BLAS Threads

Set in `~/.zshenv` (already in dotfiles):

```bash
export OMP_NUM_THREADS=6
export OPENBLAS_NUM_THREADS=6
export MKL_NUM_THREADS=6
```

## 7. Boot-time Performance Script

Create `/etc/rc.local` or a systemd service:

```bash
#!/bin/bash
# /usr/local/bin/jetson-perf.sh
nvpmodel -m 0
jetson_clocks
echo 255 > /sys/devices/pwm-fan/target_pwm
```

```bash
sudo chmod +x /usr/local/bin/jetson-perf.sh
```

systemd service:

```ini
# /etc/systemd/system/jetson-perf.service
[Unit]
Description=Jetson Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/jetson-perf.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable jetson-perf
```

## 8. Monitor Everything

```bash
# Real-time stats
sudo tegrastats

# jtop (recommended)
sudo jtop

# GPU frequency
cat /sys/devices/gpu.0/devfreq/17000000.ga10b/cur_freq

# CPU frequencies
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
```

## Quick Checklist — Max Performance

```bash
sudo nvpmodel -m 0         # MAXN power mode
sudo jetson_clocks          # lock max frequencies
sudo jetson_clocks --fan    # max fan
```
