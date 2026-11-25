#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  radar-ctl.sh — AWR6243 / IWR6243 boot-mode and reset control        ║
# ║                                                                      ║
# ║  The xWR6243 senses SOP0/SOP1/SOP2 while NRESET is released and      ║
# ║  latches its boot mode from them (datasheet SWRS283A, Table 7-1):    ║
# ║                                                                      ║
# ║    SOP2 SOP1 SOP0 = 0 0 1   functional SPI   (normal operation)      ║
# ║    SOP2 SOP1 SOP0 = 1 0 1   flashing         (development only)      ║
# ║    SOP2 SOP1 SOP0 = 0 1 1   debug                                    ║
# ║    SOP2 SOP1 SOP0 = 1 1 1   functional I2C                           ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    bash radar-ctl.sh status                                          ║
# ║    bash radar-ctl.sh mode spi|i2c|flash|debug                        ║
# ║    bash radar-ctl.sh reset                                           ║
# ║    bash radar-ctl.sh boot spi      # hold SOP, pulse NRESET, hold on  ║
# ║    bash radar-ctl.sh release       # drop the SOP hold                ║
# ║    bash radar-ctl.sh power on|off  # only if AWR6243_LINE_PWR_EN set  ║
# ║                                                                      ║
# ║  Needs libgpiod (gpioset/gpioget/gpioinfo) and a filled-in           ║
# ║  board.env — the host GPIO lines are board specific.                 ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOARD_ENV="${AWR6243_BOARD_ENV:-$SCRIPT_DIR/board.env}"
HOLD_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/awr6243-sop.pid"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}--- $* ---${NC}"; }
detail()  { echo -e "    ${CYAN}->${NC} $*"; }

usage() {
    sed -n '2,23p' "$0"
}

# ─── Board config ────────────────────────────────────────────────────
if [ ! -f "$BOARD_ENV" ]; then
    error "No board config at $BOARD_ENV"
    error "Create one:  cp $SCRIPT_DIR/board.env.example $SCRIPT_DIR/board.env"
    exit 1
fi
# shellcheck disable=SC1090
source "$BOARD_ENV"

GPIOCHIP="${AWR6243_GPIOCHIP:-gpiochip0}"
RESET_HOLD_S="${AWR6243_RESET_HOLD_S:-0.005}"
RESET_SETTLE_S="${AWR6243_RESET_SETTLE_S:-0.100}"

# ─── libgpiod flavour detection ──────────────────────────────────────
GPIOD_MAJOR=1
detect_gpiod() {
    if ! command -v gpioset &>/dev/null; then
        error "libgpiod tools not found. Install them:"
        error "  sudo apt-get install -y gpiod libgpiod-dev"
        exit 1
    fi
    local ver
    ver="$(gpioset --version 2>/dev/null | head -1 || true)"
    case "$ver" in
        *" 2."*) GPIOD_MAJOR=2 ;;
        *" 1."*) GPIOD_MAJOR=1 ;;
        *)       GPIOD_MAJOR=1
                 warn "Unrecognised libgpiod version ($ver); assuming v1 syntax" ;;
    esac
}

require_line() {
    local name="$1" value="$2"
    if [ -z "$value" ]; then
        error "$name is not set in $BOARD_ENV — fill in your carrier's GPIO offsets."
        error "Find them with:  gpiodetect ; gpioinfo"
        exit 1
    fi
}

# Set one line and release it immediately — fine for an NRESET pulse.
gpio_set_once() {
    local offset="$1" value="$2"
    if [ "$GPIOD_MAJOR" = "2" ]; then
        gpioset --chip "$GPIOCHIP" "${offset}=${value}"
    else
        gpioset "$GPIOCHIP" "${offset}=${value}"
    fi
}

gpio_get() {
    local offset="$1"
    if [ "$GPIOD_MAJOR" = "2" ]; then
        gpioget --chip "$GPIOCHIP" "$offset" 2>/dev/null || echo "?"
    else
        gpioget "$GPIOCHIP" "$offset" 2>/dev/null || echo "?"
    fi
}

# Hold a set of "offset=value" assignments for as long as the holder runs.
# gpioset drops its lines when it exits, so a background holder is the only
# way to keep SOP strapped while NRESET is released.
gpio_hold() {
    stop_hold
    if [ "$#" -eq 0 ]; then
        return 0
    fi
    local pid
    if [ "$GPIOD_MAJOR" = "2" ]; then
        # v2: a final toggle period of 0 means "hold until signalled"
        gpioset --chip "$GPIOCHIP" --toggle 0 "$@" &
    else
        gpioset --mode=signal "$GPIOCHIP" "$@" &
    fi
    pid=$!
    echo "$pid" > "$HOLD_PID_FILE"
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$HOLD_PID_FILE"
        error "Could not hold the SOP lines (gpioset exited immediately)."
        error "Check the offsets in $BOARD_ENV and that nothing else owns them (gpioinfo)."
        exit 1
    fi
    info "Holding SOP lines (pid $pid): $*"
}

stop_hold() {
    if [ -f "$HOLD_PID_FILE" ]; then
        local pid
        pid="$(cat "$HOLD_PID_FILE")"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            info "Released SOP hold (pid $pid)."
        fi
        rm -f "$HOLD_PID_FILE"
    fi
}

# echoes "SOP2 SOP1 SOP0" for a named boot mode
sop_values_for_mode() {
    case "$1" in
        spi)   echo "0 0 1" ;;
        flash) echo "1 0 1" ;;
        debug) echo "0 1 1" ;;
        i2c)   echo "1 1 1" ;;
        *)     error "Unknown boot mode: $1 (want spi|i2c|flash|debug)"; exit 1 ;;
    esac
}

strap_mode() {
    local mode="$1"
    require_line AWR6243_LINE_SOP0 "${AWR6243_LINE_SOP0:-}"
    require_line AWR6243_LINE_SOP1 "${AWR6243_LINE_SOP1:-}"
    require_line AWR6243_LINE_SOP2 "${AWR6243_LINE_SOP2:-}"

    local vals sop2 sop1 sop0
    vals="$(sop_values_for_mode "$mode")"
    read -r sop2 sop1 sop0 <<EOF
$vals
EOF

    section "Boot mode: $mode  (SOP2 SOP1 SOP0 = $sop2 $sop1 $sop0)"
    gpio_hold "${AWR6243_LINE_SOP2}=${sop2}" \
              "${AWR6243_LINE_SOP1}=${sop1}" \
              "${AWR6243_LINE_SOP0}=${sop0}"
    if [ "$mode" = "flash" ]; then
        warn "Flashing mode is a development path: the datasheet marks QSPI as"
        warn "development-only and not supported in production."
    fi
}

pulse_reset() {
    require_line AWR6243_LINE_NRESET "${AWR6243_LINE_NRESET:-}"
    section "NRESET pulse"
    detail "low for ${RESET_HOLD_S}s (datasheet minimum 20 us), then released"
    gpio_set_once "$AWR6243_LINE_NRESET" 0
    sleep "$RESET_HOLD_S"
    gpio_set_once "$AWR6243_LINE_NRESET" 1
    sleep "$RESET_SETTLE_S"
    info "Device released from reset."
    detail "The host must now download the firmware over SPI and wait for the"
    detail "power-up async event before sending any configuration API."
}

show_status() {
    section "AWR6243 control lines ($GPIOCHIP, libgpiod v$GPIOD_MAJOR)"
    local pairs=(
        "NRESET:${AWR6243_LINE_NRESET:-}"
        "SOP0:${AWR6243_LINE_SOP0:-}"
        "SOP1:${AWR6243_LINE_SOP1:-}"
        "SOP2:${AWR6243_LINE_SOP2:-}"
        "HOST_INTR:${AWR6243_LINE_HOST_INTR:-}"
        "NERROR_OUT:${AWR6243_LINE_NERROR:-}"
        "PWR_EN:${AWR6243_LINE_PWR_EN:-}"
        "SYNC_IN:${AWR6243_LINE_SYNC_IN:-}"
    )
    local pair name offset
    for pair in "${pairs[@]}"; do
        name="${pair%%:*}"
        offset="${pair#*:}"
        if [ -z "$offset" ]; then
            printf '    %-11s %s\n' "$name" "(not configured)"
        else
            printf '    %-11s line %-4s value %s\n' "$name" "$offset" "$(gpio_get "$offset")"
        fi
    done

    echo ""
    if [ -f "$HOLD_PID_FILE" ] && kill -0 "$(cat "$HOLD_PID_FILE")" 2>/dev/null; then
        info "SOP hold active (pid $(cat "$HOLD_PID_FILE"))"
    else
        detail "No SOP hold running — SOP levels come from the board straps."
    fi

    local spidev="${AWR6243_SPIDEV:-/dev/spidev0.0}"
    if [ -e "$spidev" ]; then
        info "SPI master: $spidev"
    else
        warn "SPI master $spidev not present (run: bash mmwave/setup-awr6243.sh --check)"
    fi
}

power_rail() {
    require_line AWR6243_LINE_PWR_EN "${AWR6243_LINE_PWR_EN:-}"
    case "$1" in
        on)  gpio_set_once "$AWR6243_LINE_PWR_EN" 1; info "Power enable asserted." ;;
        off) gpio_set_once "$AWR6243_LINE_PWR_EN" 0; info "Power enable deasserted." ;;
        *)   error "Usage: $0 power on|off"; exit 1 ;;
    esac
}

# ─── Dispatch ────────────────────────────────────────────────────────
detect_gpiod

case "${1:-status}" in
    status)  show_status ;;
    mode)    strap_mode "${2:?Usage: $0 mode spi|i2c|flash|debug}" ;;
    reset)   pulse_reset ;;
    boot)
        strap_mode "${2:-spi}"
        pulse_reset
        info "Boot mode held. Run '$0 release' once the host has booted the device."
        ;;
    release) stop_hold ;;
    power)   power_rail "${2:?Usage: $0 power on|off}" ;;
    --help|-h|help) usage ;;
    *)
        error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
