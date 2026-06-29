#!/bin/bash
# Detect boot method from a mounted /boot (LinuxLoader vs EFI/GRUB).
set -euo pipefail

BOOT_PROFILE_MARKER=".boot-profile"

detect_boot_profile() {
    local boot_root="${1:-/boot}"

    if [[ "${BOOT_PROFILE:-auto}" != "auto" ]]; then
        case "${BOOT_PROFILE}" in
            linuxloader|efi) echo "${BOOT_PROFILE}"; return 0 ;;
            *)
                echo "Unknown BOOT_PROFILE=${BOOT_PROFILE} (use auto, linuxloader, or efi)" >&2
                return 1
                ;;
        esac
    fi

    if [[ -f "${boot_root}/EFI/BOOT/BOOTAA64.EFI" || -f "${boot_root}/EFI/BOOT/grub.cfg" ]]; then
        echo "efi"
        return 0
    fi

    if [[ -f "${boot_root}/LinuxLoader.cfg" ]]; then
        echo "linuxloader"
        return 0
    fi

    if [[ -f "${boot_root}/boot/grub/grub.cfg" ]] && grep -qE 'menuentry|configfile' "${boot_root}/boot/grub/grub.cfg" 2>/dev/null; then
        echo "efi"
        return 0
    fi

    echo "unknown"
}

boot_profile_label() {
    case "${1}" in
        linuxloader) echo "LinuxLoader (Armbian classic)" ;;
        efi)         echo "EFI / GRUB (ROCKNIX ABL)" ;;
        *)           echo "${1}" ;;
    esac
}

boot_profile_from_build() {
    local build_boot="$1"

    if [[ -f "${build_boot}/${BOOT_PROFILE_MARKER}" ]]; then
        tr -d '[:space:]' < "${build_boot}/${BOOT_PROFILE_MARKER}"
        return 0
    fi

    if [[ -f "${build_boot}/EFI/BOOT/grub.cfg" ]]; then
        echo "efi"
        return 0
    fi

    if [[ -f "${build_boot}/LinuxLoader.cfg" ]]; then
        echo "linuxloader"
        return 0
    fi

    detect_boot_profile "${INSTALL_BOOT_SRC:-/boot}"
}
