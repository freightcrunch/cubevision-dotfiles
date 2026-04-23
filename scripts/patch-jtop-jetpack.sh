#!/usr/bin/env bash
# ------------------------------------------------------------------
# patch-jtop-jetpack.sh
#
# Patches the jetson-stats NVIDIA_JETPACK lookup table so that jtop
# correctly detects JetPack versions for L4T releases not yet known
# to the installed jetson-stats package.
#
# Run after:  sudo pip3 install -U jetson-stats
# Usage:      sudo bash patch-jtop-jetpack.sh
# ------------------------------------------------------------------
set -euo pipefail

VARS_FILE=$(python3 -c "import jtop, os; print(os.path.join(os.path.dirname(jtop.__file__), 'core', 'jetson_variables.py'))" 2>/dev/null)

if [[ ! -f "$VARS_FILE" ]]; then
    echo "ERROR: jetson_variables.py not found. Is jetson-stats installed?"
    exit 1
fi

# Map of L4T versions missing from upstream jetson-stats.
# Add new entries here as needed:  ["L4T"]="JetPack"
declare -A PATCHES=(
    ["36.4.7"]="6.2.1"
)

changed=false

for l4t in "${!PATCHES[@]}"; do
    jp="${PATCHES[$l4t]}"
    if grep -q "\"${l4t}\"" "$VARS_FILE"; then
        echo "OK: L4T ${l4t} -> JetPack ${jp} (already present)"
    else
        # Insert above the first JP6 entry
        sed -i "s|# -------- JP6 --------|# -------- JP6 --------\n    \"${l4t}\": \"${jp}\",|" "$VARS_FILE"
        echo "PATCHED: L4T ${l4t} -> JetPack ${jp}"
        changed=true
    fi
done

if $changed; then
    echo "Restarting jtop.service ..."
    systemctl restart jtop.service
    echo "Done. Run 'jtop' to verify."
else
    echo "No changes needed."
fi
