#!/bin/bash
# Assemble boot/ — auto-detects LinuxLoader vs EFI/GRUB on the running device.
set -euo pipefail

# shellcheck source=lib/boot/detect.sh
source "${ROOT}/lib/boot/detect.sh"
# shellcheck source=lib/boot/linuxloader.sh
source "${ROOT}/lib/boot/linuxloader.sh"
# shellcheck source=lib/boot/efi.sh
source "${ROOT}/lib/boot/efi.sh"

BOOT_SOURCE="${BOOT_SOURCE:-/boot}"

primary_dtb_for_device() {
    local device="$1"
    case "${device}" in
        all)    echo "qcs8550-ayn-odin2.dtb" ;;
        odin2)  echo "qcs8550-ayn-odin2.dtb" ;;
        portal) echo "qcs8550-ayn-odin2portal.dtb" ;;
        mini)   echo "qcs8550-ayn-odin2mini.dtb" ;;
        thor)   echo "qcs8550-ayn-thor.dtb" ;;
        *)      echo "qcs8550-ayn-odin2.dtb" ;;
    esac
}

assemble_boot_folder() {
    local out_dir="$1" ver="$2" device_choice="$3"
    local release="${ver}${KERNEL_LOCALVERSION}"
    local staging="${out_dir}/.staging"
    local boot="${out_dir}/boot"
    local initrd_name="initrd.img-${release}"
    local primary_dtb profile

    primary_dtb="$(primary_dtb_for_device "${device_choice}")"
    profile="$(detect_boot_profile "${BOOT_SOURCE}")"

    if [[ "${profile}" == "unknown" ]]; then
        echo "Cannot detect boot method under ${BOOT_SOURCE}/." >&2
        echo "  Expected LinuxLoader.cfg or EFI/BOOT/grub.cfg (ROCKNIX ABL)." >&2
        return 1
    fi

    mkdir -p "${boot}"

    echo "==> Assembling boot/ folder ($(boot_profile_label "${profile}"))..." >&2

    cp -f "${staging}/Image" "${boot}/Image"
    cp -f "${staging}/config-${release}" "${boot}/config-${release}"
    cp -f "${staging}/System.map" "${boot}/System.map-${release}"

    if [[ -f "${staging}/${initrd_name}" ]]; then
        cp -f "${staging}/${initrd_name}" "${boot}/${initrd_name}"
        echo "  ${initrd_name}" >&2
    else
        echo "  MISSING: ${initrd_name}" >&2
        return 1
    fi

    shopt -s nullglob
    local dtb
    for dtb in "${staging}/dtbs"/*.dtb; do
        cp -f "${dtb}" "${boot}/"
        echo "  $(basename "${dtb}")" >&2
    done
    shopt -u nullglob

    case "${profile}" in
        linuxloader)
            if [[ -f "${staging}/uInitrd" ]]; then
                cp -f "${staging}/uInitrd" "${boot}/uInitrd"
            fi
            assemble_linuxloader_boot_extras "${boot}" "${initrd_name}"
            generate_linuxloader_cfg "${boot}" "${release}" "${primary_dtb}"
            ;;
        efi)
            assemble_efi_boot_extras "${boot}" "${release}" "${primary_dtb}" "${device_choice}"
            ;;
    esac

    echo "${profile}" > "${boot}/${BOOT_PROFILE_MARKER}"

    rm -rf "${staging}"
    echo "  boot/ ready (${profile})" >&2
}
