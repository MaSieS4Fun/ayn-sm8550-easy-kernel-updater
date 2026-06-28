#!/bin/bash
# ayn-sm8550-kernel — interactive kernel builder for AYN SM8550 handhelds
# Run on the device itself (ROCKNIX-trimmed firmware + local AYN overlays).
#
# Usage: ./make_kernel.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT
export CACHE_DIR="${ROOT}/.cache"
export PATCH_CACHE="${CACHE_DIR}/armbian-patches"
export OUTPUT_DIR="${ROOT}/output"

mkdir -p "${OUTPUT_DIR}" "${CACHE_DIR}"

# shellcheck source=config/defaults.conf
source "${ROOT}/config/defaults.conf"
# shellcheck source=config/firmware.conf
source "${ROOT}/config/firmware.conf"
# shellcheck source=config/perf-profiles.conf
source "${ROOT}/config/perf-profiles.conf"
source "${ROOT}/lib/ui.sh"
source "${ROOT}/lib/kernel-org.sh"
source "${ROOT}/lib/download.sh"
source "${ROOT}/lib/armbian-support.sh"
source "${ROOT}/lib/golden.sh"
source "${ROOT}/lib/patches.sh"
source "${ROOT}/lib/kconfig.sh"
source "${ROOT}/lib/build.sh"
source "${ROOT}/lib/firmware.sh"
source "${ROOT}/lib/initramfs.sh"
source "${ROOT}/lib/boot.sh"
source "${ROOT}/lib/verify-eas.sh"

main() {
    ui_banner
    if [[ "$(_ui_cmd)" == "plain" ]]; then
        echo "Text mode (non-TTY terminal or UI=plain)."
        echo "For graphical menus, run from Konsole or a system terminal."
        echo ""
    fi
    check_build_deps || exit 1
    check_running_on_device
    ensure_golden_config || true
    refresh_armbian_support

    local kernel_ver device_choice patch_set src_dir out_dir

    if [[ -n "${KERNEL_VER}" ]]; then
        kernel_is_supported "${KERNEL_VER}" || {
            echo "KERNEL_VER=${KERNEL_VER} is not supported by current Armbian patch sets." >&2
            exit 1
        }
        SELECTED_KERNEL_VER="${KERNEL_VER}"
        echo "Using KERNEL_VER=${KERNEL_VER}" >&2
    else
        ui_select_kernel || { echo "Kernel selection cancelled or failed." >&2; exit 1; }
        kernel_ver="${SELECTED_KERNEL_VER}"
    fi
    kernel_ver="${SELECTED_KERNEL_VER}"

    ui_select_device || { echo "Device selection cancelled or failed." >&2; exit 1; }
    device_choice="${SELECTED_DEVICE}"

    patch_set="$(patch_set_for_version "${kernel_ver}")" || exit 1

    ui_confirm_build "${kernel_ver}" "${device_choice}" "${patch_set}" || exit 0

    src_dir="$(download_kernel_source "${kernel_ver}")"
    apply_armbian_patches "${src_dir}" "${patch_set}" "${kernel_ver}"
    verify_eas_in_dtsi "${src_dir}/arch/arm64/boot/dts/qcom/sm8550.dtsi"
    prepare_kernel_config "${src_dir}" "${kernel_ver}"
    build_kernel "${src_dir}" "${kernel_ver}" "${device_choice}"
    out_dir="${BUILD_OUT_DIR}"
    prepare_firmware "${out_dir}"
    build_initramfs "${out_dir}"
    assemble_boot_folder "${out_dir}" "${kernel_ver}" "${device_choice}"
    write_manifest "${out_dir}" "${kernel_ver}" "${device_choice}"

    ui_build_complete "${out_dir}"
}

main "$@"
