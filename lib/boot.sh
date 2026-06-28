#!/bin/bash
# Assemble boot/ folder and patch LinuxLoader.cfg from the running system
set -euo pipefail

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

generate_linuxloader_cfg() {
    local boot_dir="$1" release="$2" dtb="$3"
    local initrd_name="initrd.img-${release}"
    local src="/boot/LinuxLoader.cfg"
    local dest="${boot_dir}/LinuxLoader.cfg"

    if [[ ! -f "${src}" ]]; then
        echo "Missing ${src} — run this script on the AYN device." >&2
        return 1
    fi

    cp -f "${src}" "${dest}"

    sed -i "s|^initrd = .*|initrd = \"${initrd_name}\"|" "${dest}"
    sed -i "s|^devicetree = .*|devicetree = \"${dtb}\"|" "${dest}"

    echo "  LinuxLoader.cfg (from /boot, initrd=${initrd_name}, devicetree=${dtb})" >&2
}

assemble_boot_folder() {
    local out_dir="$1" ver="$2" device_choice="$3"
    local release="${ver}${KERNEL_LOCALVERSION}"
    local staging="${out_dir}/.staging"
    local boot="${out_dir}/boot"
    local initrd_name="initrd.img-${release}"
    local primary_dtb

    primary_dtb="$(primary_dtb_for_device "${device_choice}")"

    mkdir -p "${boot}"

    echo "==> Assembling boot/ folder..." >&2

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

    if [[ -f "${staging}/uInitrd" ]]; then
        cp -f "${staging}/uInitrd" "${boot}/uInitrd"
    elif command -v mkimage >/dev/null 2>&1; then
        mkimage -A arm64 -O linux -T ramdisk -C gzip \
            -d "${boot}/${initrd_name}" "${boot}/uInitrd" >/dev/null
    fi

    shopt -s nullglob
    local dtb
    for dtb in "${staging}/dtbs"/*.dtb; do
        cp -f "${dtb}" "${boot}/"
        echo "  $(basename "${dtb}")" >&2
    done
    shopt -u nullglob

    generate_linuxloader_cfg "${boot}" "${release}" "${primary_dtb}"

    rm -rf "${staging}"
    echo "  boot/ ready" >&2
}
