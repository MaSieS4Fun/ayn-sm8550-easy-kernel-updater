#!/bin/bash
set -euo pipefail

resolve_dtbs() {
    local choice="$1"
    if [[ "${choice}" == "all" ]]; then
        while IFS='|' read -r id dtb label; do
            [[ -z "${id}" || "${id}" =~ ^# ]] && continue
            echo "${dtb}"
        done < "${ROOT}/config/devices.conf"
        return 0
    fi
    while IFS='|' read -r id dtb label; do
        [[ -z "${id}" || "${id}" =~ ^# ]] && continue
        [[ "${id}" == "${choice}" ]] && echo "${dtb}" && return 0
    done < "${ROOT}/config/devices.conf"
    echo "Unknown device: ${choice}" >&2
    return 1
}

build_kernel() {
    local src_dir="$1" ver="$2" device_choice="$3"
    local release="${ver}${KERNEL_LOCALVERSION}"
    local out="${OUTPUT_DIR}/${release}"
    local staging="${out}/.staging"
    local dtb_staging="${staging}/dtbs"
    local modules_out="${out}/modules/${release}"
    local -a dtb_targets=()
    local dtb base

    rm -rf "${staging}" "${out}/modules" "${out}/boot" "${out}/firmware"
    mkdir -p "${dtb_staging}" "${modules_out}"

    while IFS= read -r dtb; do
        # Kernel Makefile prepends arch/arm64/boot/dts/ — use qcom/foo.dtb only
        dtb_targets+=("qcom/${dtb}.dtb")
    done < <(resolve_dtbs "${device_choice}")

    echo "==> Building kernel ${release} (${JOBS} jobs)..." >&2
    echo "==> DTBs: ${#dtb_targets[@]} AYN target(s) only (not all qcom boards)" >&2

    make -C "${src_dir}" ARCH=arm64 -j"${JOBS}" Image modules
    make -C "${src_dir}" ARCH=arm64 -j"${JOBS}" "${dtb_targets[@]}"

    [[ -f "${src_dir}/arch/arm64/boot/Image" ]] || {
        echo "Kernel build failed: Image not found" >&2
        return 1
    }

    cp -f "${src_dir}/arch/arm64/boot/Image" "${staging}/Image"
    cp -f "${src_dir}/System.map" "${staging}/System.map"
    cp -f "${src_dir}/.config" "${staging}/config-${release}"

    for dtb in "${dtb_targets[@]}"; do
        base="$(basename "${dtb}")"
        if [[ -f "${src_dir}/arch/arm64/boot/dts/qcom/${base}" ]]; then
            cp -f "${src_dir}/arch/arm64/boot/dts/qcom/${base}" "${dtb_staging}/${base}"
            echo "  DTB ${base}" >&2
        else
            echo "  MISSING DTB: ${base}" >&2
            return 1
        fi
    done

    rm -rf "${out}/.modules-staging"
    make -C "${src_dir}" ARCH=arm64 \
        modules_install INSTALL_MOD_PATH="${out}/.modules-staging" INSTALL_MOD_STRIP=1

    rm -rf "${modules_out}"
    mv "${out}/.modules-staging/lib/modules/${release}" "${modules_out}/"
    rm -rf "${out}/.modules-staging"

    echo "  modules/${release}/ ($(find "${modules_out}" -name '*.ko' 2>/dev/null | wc -l) modules)" >&2

    BUILD_OUT_DIR="${out}"
}
