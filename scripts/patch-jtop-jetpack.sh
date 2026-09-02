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
    ["39.2.1"]="7.2.1"
    ["39.2"]="7.2"
    ["39.1"]="7.1.1"
    ["39.0"]="7.1"
    ["36.4.7"]="6.2.1"
)

# Insertion anchor inside NVIDIA_JETPACK dict. Newer entries go above JP6;
# fall back to the opening of the dict if the marker is missing (newer
# jetson-stats may restructure the table).
ANCHOR='# -------- JP6 --------'
if ! grep -q "$ANCHOR" "$VARS_FILE"; then
    ANCHOR='NVIDIA_JETPACK = {'
fi

changed=false

for l4t in "${!PATCHES[@]}"; do
    jp="${PATCHES[$l4t]}"
    if grep -q "\"${l4t}\"" "$VARS_FILE"; then
        echo "OK: L4T ${l4t} -> JetPack ${jp} (already present)"
    else
        sed -i "s|$ANCHOR|$ANCHOR\n    \"${l4t}\": \"${jp}\",|" "$VARS_FILE"
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
