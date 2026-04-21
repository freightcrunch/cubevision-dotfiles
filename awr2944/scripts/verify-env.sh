#!/usr/bin/env bash
# ============================================================================
# verify-env.sh — run a series of non-destructive checks to confirm the dev
# environment is set up correctly on either macOS or arm64 Linux.
# ============================================================================

set -uo pipefail   # NB: not -e; we want to keep checking past individual fails

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAILED=1; }
info() { printf '  \033[1;34mi\033[0m %s\n' "$*"; }
FAILED=0

section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ----- Host detection -------------------------------------------------------
section "Host"
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Detected ${OS} on ${ARCH}"

# ----- Core tools -----------------------------------------------------------
section "Core CLI tools"
for bin in git curl cmake ninja make python3 docker; do
  if command -v "$bin" >/dev/null 2>&1; then
    pass "$bin $(${bin} --version 2>&1 | head -n1)"
  else
    fail "$bin not on PATH"
  fi
done

# ----- Rust -----------------------------------------------------------------
section "Rust"
if command -v rustup >/dev/null 2>&1; then
  pass "rustup $(rustup --version | head -n1)"
  if rustup target list --installed | grep -q armv7r-none-eabihf; then
    pass "armv7r-none-eabihf target installed"
  else
    fail "armv7r-none-eabihf target missing (run: rustup target add armv7r-none-eabihf)"
  fi
  if cargo --version >/dev/null 2>&1; then pass "$(cargo --version)"; else fail "cargo missing"; fi
else
  fail "rustup not installed"
fi

# ----- ARM GCC --------------------------------------------------------------
section "ARM bare-metal toolchain"
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  pass "arm-none-eabi-gcc $(arm-none-eabi-gcc -dumpversion)"
else
  fail "arm-none-eabi-gcc not on PATH"
fi

# ----- Serial ports ---------------------------------------------------------
section "Serial ports / XDS110"
case "${OS}" in
  Darwin)
    PORTS=(/dev/tty.usbmodem*)
    if [[ -e "${PORTS[0]}" ]]; then
      pass "USB serial devices:"; for p in "${PORTS[@]}"; do printf '      %s\n' "$p"; done
    else
      info "No /dev/tty.usbmodem* found — plug the AWR2944EVM in and re-run."
    fi
    ;;
  Linux)
    PORTS=(/dev/ttyACM*)
    if [[ -e "${PORTS[0]}" ]]; then
      pass "USB serial devices:"; for p in "${PORTS[@]}"; do printf '      %s (%s)\n' "$p" "$(stat -c '%U:%G mode=%a' "$p")"; done
    else
      info "No /dev/ttyACM* found — plug the AWR2944EVM in and re-run."
    fi
    if [[ -f /etc/udev/rules.d/71-ti-xds110.rules ]]; then
      pass "XDS110 udev rules installed"
    else
      fail "udev rules missing — re-run bootstrap-linux-arm64.sh"
    fi
    ;;
esac

# ----- Docker image ---------------------------------------------------------
section "Docker image"
if docker image inspect awr2944-sdk:latest >/dev/null 2>&1; then
  pass "awr2944-sdk:latest is built"
else
  info "awr2944-sdk:latest not built yet — run 'cd docker && docker compose build'"
fi

# ----- Rust workspace sanity ------------------------------------------------
section "Rust workspace parses"
if (cd "${REPO_ROOT}/rust" && cargo metadata --no-deps --format-version 1 >/dev/null 2>&1); then
  pass "Cargo workspace resolves cleanly"
else
  fail "Cargo workspace failed to resolve — run 'cargo metadata' in rust/ for details"
fi

# ----- Summary --------------------------------------------------------------
echo
if [[ "${FAILED}" -eq 0 ]]; then
  printf '\033[1;32m✓ environment looks good\033[0m\n'
  exit 0
else
  printf '\033[1;31m✗ %d check(s) failed — see docs/05-troubleshooting.md\033[0m\n' "$FAILED"
  exit 1
fi
