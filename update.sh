#!/bin/bash
# Install a built kernel to the running system (backup, update, optional reboot).
#
# Usage: ./update.sh
#   UPDATE_BUILD=output/7.0.14-edge-sm8550  ./update.sh   # skip menu
#   SKIP_REBOOT=1 ./update.sh                              # never reboot
#
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    exec sudo -- "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT
export OUTPUT_DIR="${ROOT}/output"

# shellcheck source=config/defaults.conf
source "${ROOT}/config/defaults.conf"
source "${ROOT}/lib/install.sh"

install_system_paths

echo "============================================================"
echo "  AYN SM8550 Kernel Install"
echo "  Backup -> output/old_kernel/  |  Install -> /boot, firmware, modules"
echo "============================================================"
echo ""
echo "Running kernel: $(uname -r)"
echo ""

install_pick_build || exit 1
build="${SELECTED_INSTALL_BUILD}"
release="$(basename "${build}")"

echo "Build to install: ${build}"
echo "  boot/     -> ${INSTALL_BOOT_SRC}/"
echo "  firmware/ -> ${INSTALL_FIRMWARE_SRC}/"
echo "  modules/  -> ${INSTALL_MODULES_SRC}/${release}/"
echo ""
echo "Current system will be saved to: ${OUTPUT_DIR}/old_kernel/"
echo ""

if [[ -t 0 ]]; then
    read -r -p "Continue with backup and install? [y/N] " ans
    [[ "${ans,,}" == "y" ]] || { echo "Cancelled."; exit 0; }
fi

install_backup_running
install_from_build "${build}"
install_prompt_reboot
