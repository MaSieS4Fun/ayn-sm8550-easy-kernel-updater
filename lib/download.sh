#!/bin/bash
set -euo pipefail

download_kernel_source() {
    local ver="$1"
    local url dest tar src_dir
    url="$(kernel_tarball_url "${ver}")"
    dest="${CACHE_DIR}/linux-${ver}"
    tar="${CACHE_DIR}/linux-${ver}.tar.xz"
    src_dir="${dest}"

    if [[ -f "${src_dir}/Makefile" ]]; then
        local mkver
        mkver="$(make -s -C "${src_dir}" kernelversion 2>/dev/null || true)"
        if [[ "${mkver}" == "${ver}" ]]; then
            echo "${src_dir}"
            return 0
        fi
    fi

    echo "==> Downloading linux-${ver} from kernel.org" >&2
    if [[ ! -f "${tar}" ]]; then
        curl -fL --progress-bar --max-time 600 -o "${tar}.partial" "${url}"
        mv "${tar}.partial" "${tar}"
    fi

    rm -rf "${dest}"
    echo "==> Extracting linux-${ver}" >&2
    tar -xJf "${tar}" -C "${CACHE_DIR}"
    echo "${src_dir}"
}

fetch_armbian_defconfig() {
    local dest="${CACHE_DIR}/linux-sm8550-edge.config"
    if [[ ! -f "${dest}" ]]; then
        echo "==> Fetching Armbian sm8550 defconfig" >&2
        curl -fsSL --max-time 30 \
            "${ARMBIAN_PATCH_RAW}/config/kernel/linux-sm8550-edge.config" \
            -o "${dest}"
    fi
    echo "${dest}"
}

fetch_armbian_patches() {
    local patch_set="$1"
    local dest="${PATCH_CACHE}/${patch_set}"
    local api="https://api.github.com/repos/armbian/build/contents/patch/kernel/archive/${patch_set}"

    if [[ -d "${dest}" && -n "$(ls -A "${dest}"/*.patch 2>/dev/null)" ]]; then
        echo "${dest}"
        return 0
    fi

    echo "==> Fetching patches ${patch_set}" >&2
    mkdir -p "${dest}"

    local names
    names="$(curl -fsSL --max-time 60 "${api}" | python3 -c "
import sys, json
for item in sorted(json.load(sys.stdin), key=lambda x: x['name']):
    if item['name'].endswith('.patch'):
        print(item['name'])
")"

    local name
    for name in ${names}; do
        curl -fsSL --max-time 60 \
            "${ARMBIAN_PATCH_RAW}/patch/kernel/archive/${patch_set}/${name}" \
            -o "${dest}/${name}"
    done
    echo "${dest}"
}
