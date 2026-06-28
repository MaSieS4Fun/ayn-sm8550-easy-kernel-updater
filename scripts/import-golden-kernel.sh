#!/bin/bash
# Import known-good 6.18.8 boot artifacts into ayn-sm8550-kernel for analysis/builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-/home/odin2/Projects/kernel-6.18.8-rendimineto}"
DEST_CFG="${ROOT}/config/golden.config"
DEST_INITRD="${ROOT}/config/golden-initrd.img"

GOLD_CFG="${SRC}/boot/config-6.18.8-edge-sm8550"
GOLD_INITRD="${SRC}/boot/initrd.img-6.18.8-edge-sm8550"

[[ -d "${SRC}" ]] || { echo "Missing: ${SRC}" >&2; exit 1; }
mkdir -p "${ROOT}/config" "${ROOT}/output"

echo "Import from: ${SRC}"

if [[ -f "${GOLD_CFG}" ]]; then
    cp -f "${GOLD_CFG}" "${DEST_CFG}"
    echo "  -> ${DEST_CFG}"
else
    echo "  !! missing ${GOLD_CFG}" >&2
fi

if [[ -f "${GOLD_INITRD}" ]]; then
    cp -f "${GOLD_INITRD}" "${DEST_INITRD}"
    echo "  -> ${DEST_INITRD} ($(du -h "${DEST_INITRD}" | cut -f1))"
else
    echo "  !! missing ${GOLD_INITRD} (optional)" >&2
fi

echo ""
echo "Next build (7.0.14 example):"
echo "  KERNEL_VER=7.0.14 UI=plain ./update.sh"
echo ""
echo "Optional: use golden initrd instead of generated (HDMI boot test):"
echo "  USE_GOLDEN_INITRD=1 KERNEL_VER=7.0.14 UI=plain ./update.sh"
