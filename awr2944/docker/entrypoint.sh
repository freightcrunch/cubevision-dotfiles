#!/usr/bin/env bash
# Dev-container entrypoint: sources TI SDK env if it's been installed, prints
# a welcome banner with key tool versions, then execs whatever CMD was passed.

set -euo pipefail

if [[ -f /ti/mmwave_mcuplus_sdk_*/scripts/unix/setenv.sh ]]; then
  # shellcheck disable=SC1090
  source /ti/mmwave_mcuplus_sdk_*/scripts/unix/setenv.sh 2>/dev/null || true
fi

cat <<EOF
┌──────────────────────────────────────────────────────────────────┐
│  AWR2944 dev container                                           │
│  arm-none-eabi-gcc : $(arm-none-eabi-gcc -dumpversion 2>/dev/null || echo 'missing')
│  rustc             : $(rustc --version 2>/dev/null || echo 'missing')
│  TI SDK prefix     : $(ls -d /ti/mmwave_mcuplus_sdk_* 2>/dev/null | head -n1 || echo 'not installed — run /opt/scripts/install-ti-sdk.sh')
│  Workspace         : /workspace
└──────────────────────────────────────────────────────────────────┘
EOF

exec "$@"
