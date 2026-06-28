#!/bin/bash
# Backup running kernel and install from output/ build tree.
set -euo pipefail

INSTALL_BOOT_SRC="${INSTALL_BOOT_SRC:-/boot}"
INSTALL_FIRMWARE_SRC="${INSTALL_FIRMWARE_SRC:-/usr/lib/firmware}"
INSTALL_MODULES_SRC="${INSTALL_MODULES_SRC:-/usr/lib/modules}"

_resolve_path() {
    readlink -f "$1" 2>/dev/null || echo "$1"
}

_install_fstype() {
    findmnt -no FSTYPE "$1" 2>/dev/null || true
}

_install_cp_tree() {
    local src="$1" dest="$2"
    local fstype
    fstype="$(_install_fstype "${dest}")"

    case "${fstype,,}" in
        vfat|fat|msdos|exfat)
            # /boot on AYN is usually FAT — ownership/mode cannot be preserved.
            cp -rf --no-preserve=ownership,mode "${src}/." "${dest}/"
            ;;
        *)
            cp -a "${src}/." "${dest}/"
            ;;
    esac
}

install_boot_is_vfat() {
    local fstype
    fstype="$(_install_fstype "${INSTALL_BOOT_SRC}")"
    case "${fstype,,}" in
        vfat|fat|msdos|exfat) return 0 ;;
        *) return 1 ;;
    esac
}

install_system_paths() {
    INSTALL_BOOT_SRC="$(_resolve_path "${INSTALL_BOOT_SRC}")"
    INSTALL_FIRMWARE_SRC="$(_resolve_path "${INSTALL_FIRMWARE_SRC}")"
    INSTALL_MODULES_SRC="$(_resolve_path "${INSTALL_MODULES_SRC}")"
}

install_list_builds() {
    local d base
    install_list_builds_result=()
    shopt -s nullglob
    for d in "${OUTPUT_DIR}"/*/; do
        base="$(basename "${d}")"
        [[ "${base}" == "old_kernel" || "${base}" == "firmware-only" ]] && continue
        [[ -d "${d}/boot" && -f "${d}/boot/Image" ]] || continue
        install_list_builds_result+=("${d%/}")
    done
    shopt -u nullglob
}

install_pick_build() {
    local build="${UPDATE_BUILD:-}" builds=() i newest=0 ts pick_ts=0

    install_list_builds
    builds=("${install_list_builds_result[@]}")

    if [[ ${#builds[@]} -eq 0 ]]; then
        echo "No kernel builds in ${OUTPUT_DIR}/. Run ./make_kernel.sh first." >&2
        return 1
    fi

    if [[ -n "${build}" ]]; then
        [[ -d "${build}/boot" ]] || build="${OUTPUT_DIR}/${build}"
        [[ -f "${build}/boot/Image" ]] || {
            echo "Build not found or incomplete: ${build}" >&2
            return 1
        }
        SELECTED_INSTALL_BUILD="${build}"
        return 0
    fi

    if [[ ${#builds[@]} -eq 1 ]]; then
        SELECTED_INSTALL_BUILD="${builds[0]}"
        return 0
    fi

    for i in "${!builds[@]}"; do
        ts="$(stat -c %Y "${builds[$i]}" 2>/dev/null || echo 0)"
        if [[ "${ts}" -ge "${pick_ts}" ]]; then
            pick_ts="${ts}"
            newest="${i}"
        fi
    done

    if [[ -t 0 ]]; then
        echo "Available kernel builds:"
        PS3="Select build to install: "
        select choice in "${builds[@]}"; do
            [[ -n "${choice}" ]] || { echo "Invalid selection." >&2; return 1; }
            SELECTED_INSTALL_BUILD="${choice}"
            break
        done
    else
        SELECTED_INSTALL_BUILD="${builds[$newest]}"
        echo "Using newest build: ${SELECTED_INSTALL_BUILD}" >&2
    fi
}

install_backup_running() {
    local backup_root="${OUTPUT_DIR}/old_kernel"

    echo "==> Backing up running kernel to ${backup_root}/" >&2

    rm -rf "${backup_root}"
    mkdir -p "${backup_root}/boot" "${backup_root}/firmware" "${backup_root}/modules"

    [[ -d "${INSTALL_BOOT_SRC}" ]] || {
        echo "Missing ${INSTALL_BOOT_SRC}" >&2
        return 1
    }
    [[ -d "${INSTALL_FIRMWARE_SRC}" ]] || {
        echo "Missing ${INSTALL_FIRMWARE_SRC}" >&2
        return 1
    }
    [[ -d "${INSTALL_MODULES_SRC}" ]] || {
        echo "Missing ${INSTALL_MODULES_SRC}" >&2
        return 1
    }

    echo "  boot/     <- ${INSTALL_BOOT_SRC}/" >&2
    cp -a "${INSTALL_BOOT_SRC}/." "${backup_root}/boot/"

    echo "  firmware/ <- ${INSTALL_FIRMWARE_SRC}/" >&2
    cp -a "${INSTALL_FIRMWARE_SRC}/." "${backup_root}/firmware/"

    echo "  modules/  <- ${INSTALL_MODULES_SRC}/" >&2
    cp -a "${INSTALL_MODULES_SRC}/." "${backup_root}/modules/"

    cat > "${backup_root}/BACKUP.txt" <<EOF
date=$(date -Iseconds)
running_kernel=$(uname -r)
boot_source=${INSTALL_BOOT_SRC}
firmware_source=${INSTALL_FIRMWARE_SRC}
modules_source=${INSTALL_MODULES_SRC}
EOF

    echo "  backup size: $(du -sh "${backup_root}" | cut -f1)" >&2
}

install_from_build() {
    local build="$1"
    local release modules_src firmware_src

    release="$(basename "${build}")"
    modules_src="${build}/modules/${release}"
    firmware_src="${build}/firmware"

    echo "==> Installing kernel from ${build}/" >&2

    [[ -f "${build}/boot/Image" ]] || {
        echo "Missing ${build}/boot/Image" >&2
        return 1
    }

    echo "  /boot/ <- boot/" >&2
    if install_boot_is_vfat; then
        echo "  (boot is FAT — copying without Unix ownership)" >&2
    fi
    _install_cp_tree "${build}/boot" "${INSTALL_BOOT_SRC}"
    sync "${INSTALL_BOOT_SRC}" 2>/dev/null || sync

    if [[ -d "${firmware_src}" ]]; then
        echo "  ${INSTALL_FIRMWARE_SRC}/ <- firmware/" >&2
        cp -a "${firmware_src}/." "${INSTALL_FIRMWARE_SRC}/"
    else
        echo "  WARNING: no firmware/ in build — skipping firmware install" >&2
    fi

    if [[ -d "${modules_src}" ]]; then
        echo "  ${INSTALL_MODULES_SRC}/${release}/ <- modules/${release}/" >&2
        mkdir -p "${INSTALL_MODULES_SRC}"
        rm -rf "${INSTALL_MODULES_SRC}/${release}"
        cp -a "${modules_src}" "${INSTALL_MODULES_SRC}/"
    else
        echo "  WARNING: no modules/${release}/ in build — skipping modules install" >&2
    fi

    cat >> "${OUTPUT_DIR}/old_kernel/BACKUP.txt" <<EOF
installed_build=${build}
installed_release=${release}
installed_date=$(date -Iseconds)
EOF

    echo "==> Install complete (${release})" >&2
}

install_prompt_reboot() {
    echo ""
    echo "============================================================"
    echo "  WARNING: A reboot is required."
    echo "  The new kernel will not be active until you restart."
    echo "============================================================"
    echo ""

    if [[ "${SKIP_REBOOT:-0}" == "1" ]]; then
        echo "SKIP_REBOOT=1 — reboot skipped."
        echo "Changes will not take effect until you reboot manually."
        return 0
    fi

    if [[ ! -t 0 ]]; then
        echo "Changes will not take effect until you reboot manually."
        return 0
    fi

    read -r -p "Reboot now? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
        echo "Rebooting..."
        systemctl reboot
    else
        echo ""
        echo "Reboot postponed."
        echo "The new kernel is installed but not running yet."
        echo "Restart when ready: sudo reboot"
    fi
}
