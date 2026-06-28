#!/bin/bash
# Refresh firmware cache and output tree without rebuilding the kernel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
export CACHE_DIR="${ROOT}/.cache"
export OUTPUT_DIR="${ROOT}/output"

# shellcheck source=config/defaults.conf
source "${ROOT}/config/defaults.conf"
# shellcheck source=config/firmware.conf
source "${ROOT}/config/firmware.conf"
source "${ROOT}/lib/firmware.sh"

out="${1:-${OUTPUT_DIR}/firmware-only}"

mkdir -p "$(dirname "${out}")"
prepare_firmware "${out}"

echo ""
echo "Firmware ready: ${out}/firmware/"
echo "  $(du -sh "${out}/firmware" | cut -f1), ${FIRMWARE_FILE_COUNT} files"
echo ""
echo "Install with: ./update.sh"
