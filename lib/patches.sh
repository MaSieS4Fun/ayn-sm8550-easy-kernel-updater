#!/bin/bash
set -euo pipefail

_patch_is_skipped() {
    local base="$1" deny_list="${2:-${PATCH_SKIP:-}}"
    local deny
    [[ -z "${deny_list}" ]] && return 1
    IFS=',' read -ra deny <<< "${deny_list}"
    local pat
    for pat in "${deny[@]}"; do
        pat="${pat// /}"
        [[ -z "${pat}" ]] && continue
        [[ "${base}" == *"${pat}"* ]] && return 0
    done
    return 1
}

apply_armbian_patches() {
    local src_dir="$1" patch_set="$2" kernel_ver="$3"
    local patch_dir failed=0 applied=0 skipped=0 denied=0
    patch_dir="$(fetch_armbian_patches "${patch_set}")"
    mkdir -p "${OUTPUT_DIR}"
    local log="${OUTPUT_DIR}/patch-log-${patch_set}.txt"
    : > "${log}"

    echo "==> Applying patches ${patch_set} (linux-${kernel_ver})" >&2
    if [[ -n "${PATCH_SKIP:-}" ]]; then
        echo "  PATCH_SKIP=${PATCH_SKIP}" >&2
    fi

    shopt -s nullglob
    local patch base
    for patch in "${patch_dir}"/*.patch; do
        base="$(basename "${patch}")"
        if _patch_is_skipped "${base}" "${PATCH_SKIP:-}"; then
            echo "  DENY ${base}" >&2
            denied=$((denied + 1))
            continue
        fi
        if patch -p1 --dry-run -d "${src_dir}" -f < "${patch}" >/dev/null 2>&1; then
            patch -p1 -d "${src_dir}" -f < "${patch}" >> "${log}" 2>&1 && {
                echo "  OK   ${base}" >&2
                applied=$((applied + 1))
            } || { echo "  FAIL ${base}" >&2; failed=$((failed + 1)); }
        elif patch -p1 --dry-run -R -d "${src_dir}" -f < "${patch}" >/dev/null 2>&1; then
            echo "  SKIP ${base} (already in tree)" >&2
            skipped=$((skipped + 1))
        else
            echo "  FAIL ${base}" >&2
            failed=$((failed + 1))
        fi
    done
    shopt -u nullglob

    echo "==> Patches: ${applied} applied, ${skipped} skipped, ${denied} denied, ${failed} failed" >&2

    if [[ "${failed}" -gt 0 ]]; then
        echo "" >&2
        echo "BUILD ABORTED: patch set does not fully apply to linux-${kernel_ver}." >&2
        echo "  Log: ${log}" >&2
        echo "  This kernel version is not ready for AYN SM8550 yet." >&2
        echo "  Use Linux 7.0.x (supported). Retry newer versions when Armbian publishes matching patches." >&2
        if [[ "${PATCH_POLICY}" == "tolerant" ]]; then
            echo "  PATCH_POLICY=tolerant — continuing anyway (not recommended)." >&2
            return 0
        fi
        return 1
    fi
    return 0
}

prepare_kernel_config() {
    local src_dir="$1" kernel_ver="$2" base
    base="$(resolve_kernel_config "${kernel_ver}")"
    [[ -f "${base}" ]] || base="$(fetch_armbian_defconfig)"

    warn_config_source "${base}"
    cp "${base}" "${src_dir}/.config"
    make -C "${src_dir}" ARCH=arm64 olddefconfig
    "${src_dir}/scripts/config" --file "${src_dir}/.config" \
        --set-str LOCALVERSION "${KERNEL_LOCALVERSION}"
    make -C "${src_dir}" ARCH=arm64 olddefconfig
    apply_gaming_config_tweaks "${src_dir}"
}
