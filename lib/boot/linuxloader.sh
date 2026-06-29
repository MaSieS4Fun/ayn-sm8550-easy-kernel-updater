#!/bin/bash
# LinuxLoader.cfg boot layout (classic Armbian on AYN SM8550).
set -euo pipefail

generate_linuxloader_cfg() {
    local boot_dir="$1" release="$2" dtb="$3"
    local initrd_name="initrd.img-${release}"
    local src="${BOOT_SOURCE:-/boot}/LinuxLoader.cfg"
    local dest="${boot_dir}/LinuxLoader.cfg"

    if [[ ! -f "${src}" ]]; then
        echo "Missing ${src} — run this script on the AYN device with LinuxLoader boot." >&2
        return 1
    fi

    cp -f "${src}" "${dest}"

    sed -i "s|^initrd = .*|initrd = \"${initrd_name}\"|" "${dest}"
    sed -i "s|^devicetree = .*|devicetree = \"${dtb}\"|" "${dest}"

    echo "  LinuxLoader.cfg (initrd=${initrd_name}, devicetree=${dtb})" >&2
}

assemble_linuxloader_boot_extras() {
    local boot_dir="$1" initrd_name="$2"

    if [[ -f "${boot_dir}/uInitrd" ]]; then
        : # copied from staging by caller
    elif command -v mkimage >/dev/null 2>&1 && [[ -f "${boot_dir}/${initrd_name}" ]]; then
        mkimage -A arm64 -O linux -T ramdisk -C gzip \
            -d "${boot_dir}/${initrd_name}" "${boot_dir}/uInitrd" >/dev/null
        echo "  uInitrd" >&2
    fi

    return 0
}
