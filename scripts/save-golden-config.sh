#!/bin/bash
# Save a known-good /boot config as config/golden.config for future builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${1:-/boot/config-6.18.8-edge-sm8550}"
dest="${ROOT}/config/golden.config"

if [[ ! -f "${src}" ]]; then
    echo "Missing: ${src}" >&2
    echo "Usage: $0 [/boot/config-VERSION]" >&2
    echo "  Or from backup: $0 /path/to/config-from-good-image" >&2
    exit 1
fi

cp -f "${src}" "${dest}"
echo "Saved golden.config from ${src}"
echo "Future builds use it automatically unless KERNEL_CONFIG is set."
