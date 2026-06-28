#!/bin/bash
# Merge ROCKNIX SM8550 kernel-firmware.dat into config/firmware-sm8550.dat
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=config/firmware.conf
source "${ROOT}/config/firmware.conf"

dest="${ROOT}/config/firmware-sm8550.dat"
tmp="$(mktemp)"
rocknix="$(mktemp)"

curl -fsSL --max-time 60 "${ROCKNIX_FIRMWARE_DAT_URL}" -o "${rocknix}"

{
    echo "# SM8550 firmware manifest — ROCKNIX trimmed set + AYN overlays"
    echo "# Auto-synced $(date -Iseconds) from:"
    echo "#   ${ROCKNIX_FIRMWARE_DAT_URL}"
    echo "# Prefixes: ? = optional, @system = prefer build-host firmware"
    echo ""
    echo "# --- ROCKNIX kernel-firmware.dat ---"
    grep -v '^[[:space:]]*#' "${rocknix}" | grep -v '^[[:space:]]*$' || true
    echo ""
    echo "# --- WiFi: Armbian system, ROCKNIX 4-file set ---"
    echo "@system ath12k/WCN7850/hw2.0/amss.bin"
    echo "@system ath12k/WCN7850/hw2.0/board-2.bin"
    echo "@system ath12k/WCN7850/hw2.0/m3.bin"
    echo "@system ath12k/WCN7850/hw2.0/regdb.bin"
    echo ""
    echo "# --- Vendor / overlay blobs ---"
    echo "@system qcom/vpu/vpu30_p4.mbn"
    echo "@system qcom/sm8550/AYN-Odin2-tplg.bin"
    echo "@system renesas_usb_fw.mem"
    echo "?@system qcom/sm8550/AYN-Thor-tplg.bin"
    echo "?@system qcom/sm8550/SM8550-APS-tplg.bin"
    echo "?@system qcom/sm8550/SM8550-HDK-tplg.bin"
    echo "?@system qcom/sm8550/SM8550-QRD-tplg.bin"
    echo "?@system qcom/sm8550/QCS8550-AYN-ODIN2-tplg.bin"
    echo ""
    echo "# --- AYN vendor firmware ---"
    echo "@system qcom/sm8550/ayn/*"
} > "${tmp}"

mv "${tmp}" "${dest}"
rm -f "${rocknix}"

echo "Updated ${dest}"
echo "Review diff, then run: ./scripts/update-firmware.sh"
