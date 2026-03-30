# Dev Environment — Nix Flake

Reproducible development environment using [Nix](https://nixos.org/) flakes, mirroring the Jetson Orin Nano host machine dependencies.

## Install Nix

### Single-user install (recommended for dev containers)

```bash
sh <(curl -L https://nixos.org/nix/install) --no-daemon
```

### Multi-user install (recommended for shared machines)

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### Enable flakes

Add the following to `~/.config/nix/nix.conf` (create the file if it doesn't exist):

```ini
experimental-features = nix-command flakes
```

Or pass it inline:

```bash
nix --experimental-features 'nix-command flakes' develop
```

## Usage

### Enter the development shell

```bash
cd dev/
nix develop
```

This drops you into a shell with **all** the tools and libraries from the host machine config pre-loaded:

- **Shell**: zsh, fzf, zoxide
- **WM utilities**: rofi, dunst, feh, scrot, xclip
- **Dev tools**: git, curl, wget, cmake, pkg-config, gcc
- **Python**: python3, pip, venv, ruff
- **Rust**: stable toolchain, clippy, rustfmt, rust-analyzer, mold linker
- **Node.js**: nodejs LTS, npm
- **CLI tools**: ripgrep, fd, bat, htop, neofetch

### Run a one-off command

```bash
nix develop --command rustc --version
```

### Build without entering the shell

```bash
nix build
```

## Updating

```bash
nix flake update
```

This updates `flake.lock` to the latest nixpkgs revision.

## Customization

Edit `flake.nix` to add or remove packages. The structure mirrors the host machine's `scripts/install.sh` package list, so changes should be kept in sync.

## Troubleshooting

- **Nix not found after install**: Source the profile: `. ~/.nix-profile/etc/profile.d/nix.sh`
- **Permission denied**: Ensure your user is in the `nix-users` group (multi-user install)
- **aarch64 packages missing**: The flake uses `flake-utils` to support multiple architectures including `aarch64-linux`
