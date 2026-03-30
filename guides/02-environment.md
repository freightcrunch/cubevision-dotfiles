# 02 — Environment Setup

## 1. System Update

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo reboot
```

## 2. Essential Packages

```bash
sudo apt-get install -y \
    build-essential cmake pkg-config git curl wget \
    python3 python3-dev python3-pip python3-venv \
    ssh zlib1g-dev software-properties-common lsb-release \
    unzip zip htop terminator \
    libssl-dev libffi-dev libfontconfig1-dev \
    libjpeg-dev zlib1g-dev libopenblas-dev libopenmpi-dev
```

## 3. SSH Access

SSH is usually pre-installed. Enable if needed:

```bash
sudo systemctl enable ssh
sudo systemctl start ssh

# Find your IP
hostname -I

# From another machine:
ssh jetson@<JETSON_IP>
```

### SSH Key Setup

```bash
# On your dev machine
ssh-keygen -t ed25519 -C "jetson"
ssh-copy-id jetson@<JETSON_IP>
```

## 4. VS Code (native ARM64)

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=arm64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo apt update
sudo apt install code
```

Or install via snap:

```bash
sudo snap install code --classic
```

## 5. Remote Development (VS Code SSH)

On your dev machine, install the **Remote - SSH** extension, then:

```
Ctrl+Shift+P → Remote-SSH: Connect to Host → jetson@<JETSON_IP>
```

## 6. Miniconda (optional)

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
chmod +x Miniconda3-latest-Linux-aarch64.sh
./Miniconda3-latest-Linux-aarch64.sh
# Follow prompts, then:
source ~/.bashrc
conda --version
```

## 7. Fix Snap Browsers (if broken)

See: [fix-snap-browsers.sh](../scripts/fix-snap-browsers.sh)

```bash
bash scripts/fix-snap-browsers.sh
```
