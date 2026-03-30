#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  polybar/launch.sh — kill existing bars, launch polybar              ║
# ║  Install to: ~/.config/polybar/launch.sh                            ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done

# Launch bar
polybar main -c "$HOME/.config/polybar/config.ini" 2>&1 | tee -a /tmp/polybar.log &
disown

echo "Polybar launched..."
