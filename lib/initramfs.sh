#!/bin/bash
set -euo pipefail

build_initramfs() {
    local out_dir="$1"
    local release
    release="$(basename "${out_dir}")"
    local staging="${out_dir}/.staging"
    local mod_root="${out_dir}/.initramfs-root"
    local initrd="${staging}/initrd.img-${release}"
    local mkinitramfs_cmd="/usr/sbin/mkinitramfs"
    local modules_src="${out_dir}/modules/${release}"

    command -v mkinitramfs >/dev/null 2>&1 || [[ -x "${mkinitramfs_cmd}" ]] || {
        echo "Install: sudo apt install initramfs-tools" >&2
        return 1
    }

    [[ -d "${modules_src}" ]] || {
        echo "Missing modules/${release}/ — build kernel first." >&2
        return 1
    }

    mkdir -p "${staging}"
    rm -rf "${mod_root}"
    mkdir -p "${mod_root}/lib/modules" "${mod_root}/etc/initramfs-tools/hooks"
    cp -a "${modules_src}" "${mod_root}/lib/modules/${release}"
    install -m755 "${ROOT}/hooks/ayn-firmware" "${mod_root}/etc/initramfs-tools/hooks/ayn-firmware"

    if [[ -d "${out_dir}/firmware" ]]; then
        echo "${out_dir}/firmware" > "${mod_root}/etc/ayn-firmware-staging"
        echo "  initramfs firmware: ${out_dir}/firmware" >&2
    fi

    if [[ "${INITRAMFS_PROFILE:-minimal}" == "minimal" ]]; then
        mkdir -p "${mod_root}/etc/initramfs-tools/conf.d"
        echo 'MODULES=dep' > "${mod_root}/etc/initramfs-tools/conf.d/ayn-minimal.conf"
        install -m755 "${ROOT}/hooks/zz-ayn-no-early-drm" \
            "${mod_root}/etc/initramfs-tools/hooks/zz-ayn-no-early-drm"
        echo "  initramfs profile: minimal (no early DRM — HDMI boot hang workaround)" >&2
    else
        echo "  initramfs profile: full" >&2
    fi

    echo "==> Building initramfs..." >&2
    if command -v mkinitramfs >/dev/null 2>&1; then
        mkinitramfs -k "${release}" -r "${mod_root}" -o "${initrd}" 2>&1 | tail -5 >&2
    else
        "${mkinitramfs_cmd}" -k "${release}" -r "${mod_root}" -o "${initrd}" 2>&1 | tail -5 >&2
    fi

    [[ -f "${initrd}" ]] || {
        echo "initramfs build failed: ${initrd} not created" >&2
        return 1
    }

    if command -v mkimage >/dev/null 2>&1; then
        mkimage -A arm64 -O linux -T ramdisk -C gzip -d "${initrd}" "${staging}/uInitrd" >/dev/null
    fi

    rm -rf "${mod_root}"
    echo "  initrd.img-${release} ($(du -h "${initrd}" | cut -f1))" >&2
}

write_manifest() {
    local out_dir="$1" ver="$2" device="$3"
    local release="${ver}${KERNEL_LOCALVERSION}"
    local manifest="${out_dir}/MANIFEST.txt"
    local install="${out_dir}/INSTALL.txt"
    local profile boot_layout boot_note

    profile="unknown"
    if [[ -f "${out_dir}/boot/.boot-profile" ]]; then
        profile="$(tr -d '[:space:]' < "${out_dir}/boot/.boot-profile")"
    fi

    case "${profile}" in
        efi)
            boot_layout="    Image, initrd, DTBs, EFI/BOOT/, boot/grub/"
            boot_note="EFI/GRUB: devicetree is set in grub.cfg (auto-patched on build/install)."
            ;;
        linuxloader)
            boot_layout="    Image, initrd, DTBs, LinuxLoader.cfg, uInitrd"
            boot_note="LinuxLoader: edit devicetree= in LinuxLoader.cfg if your device differs."
            ;;
        *)
            boot_layout="    Image, initrd, DTBs, boot config (LinuxLoader or EFI)"
            boot_note="Boot files depend on auto-detected method on the device."
            ;;
    esac

    cat > "${manifest}" <<EOF
# AYN SM8550 kernel build
Date: $(date -Iseconds)
Kernel: linux-${ver} (${release})
Boot: ${profile}
Source: kernel.org + Armbian patches (${device})
Config: gaming baseline (config/golden.config + tuning)
Initramfs: ${INITRAMFS_PROFILE:-minimal}
EAS: verified at build (A510 capacity=326)
Firmware: ${FIRMWARE_POLICY_USED:-rocknix} ($(basename "${FIRMWARE_MANIFEST:-config/firmware-sm8550.dat}"), linux-firmware-${FIRMWARE_LINUX_VERSION:-n/a})

Layout:
  boot/
${boot_layout}
  modules/${release}/
    kernel/ + modules.* metadata
  firmware/          (copy for images / backup)

SHA256:
EOF

    ( cd "${out_dir}" && find boot modules firmware -type f 2>/dev/null | sort | while read -r f; do
        sha256sum "${f}"
    done ) >> "${manifest}"

    cat > "${install}" <<EOF
# Manual installation — ${release}

Recommended: run from the project root (backup + install + reboot):

  ./update.sh

Or copy files yourself:

  sudo cp -a boot/* /boot/
  sudo cp -a modules/${release} /lib/modules/
  sudo cp -a firmware/* /lib/firmware/

Previous system is saved to output/old_kernel/ when using ./update.sh.

${boot_note}

DTB by device:
  Odin 2 Base   -> qcs8550-ayn-odin2.dtb
  Odin 2 Portal -> qcs8550-ayn-odin2portal.dtb
  Odin 2 Mini   -> qcs8550-ayn-odin2mini.dtb
  AYN Thor      -> qcs8550-ayn-thor.dtb

Reboot when ready.
EOF
}
