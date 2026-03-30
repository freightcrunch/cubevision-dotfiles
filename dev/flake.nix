# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Nix Flake — Jetson Orin Nano dev environment                       ║
# ║                                                                      ║
# ║  Mirrors all dependencies from the host machine install.sh           ║
# ║  Usage:  nix develop                                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝
{
  description = "Jetson Orin Nano — reproducible dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Rust stable with extra components (mirrors host rustup setup)
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "clippy"
            "rustfmt"
            "rust-analyzer"
            "rust-src"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "jetson-dev";

          buildInputs = with pkgs; [
            # ── Shell ──────────────────────────────────────────────
            zsh
            fzf
            zoxide

            # ── Dev tools ─────────────────────────────────────────
            git
            curl
            wget
            gnumake
            cmake
            pkg-config
            gcc

            # ── Python ────────────────────────────────────────────
            python3
            python3Packages.pip
            python3Packages.virtualenv
            ruff

            # ── Rust ──────────────────────────────────────────────
            rustToolchain
            mold

            # ── Node.js ───────────────────────────────────────────
            nodejs_20
            nodePackages.npm

            # ── Terminal / editors ──────────────────────────────────
            tmux
            neovim

            # ── CLI utilities ─────────────────────────────────────
            ripgrep
            fd
            bat
            htop
            neofetch
            silver-searcher
            tree
            jq
            stow
            unzip
            ranger

            # ── WM / desktop utilities ────────────────────────────
            rofi
            dunst
            feh
            scrot
            xclip

            # ── Libraries (Rust / Python build deps) ──────────────
            openssl
            openssl.dev
            fontconfig
            fontconfig.dev
            openblas
            libjpeg
            zlib

            # ── Cross-compilation ─────────────────────────────────
            # `cross` requires docker or podman at runtime

            # ── PyTorch build deps ────────────────────────────────
            openmpi
          ];

          # Mirror host environment variables from .zshenv
          shellHook = ''
            export OMP_NUM_THREADS=6
            export OPENBLAS_NUM_THREADS=6
            export RUSTFLAGS="-C link-arg=-fuse-ld=mold"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

            echo ""
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  Nix dev shell — Jetson Orin Nano environment                ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "  Python:  $(python3 --version)"
            echo "  Rust:    $(rustc --version)"
            echo "  Node:    $(node --version)"
            echo "  mold:    $(mold --version)"
            echo ""
          '';
        };
      }
    );
}
