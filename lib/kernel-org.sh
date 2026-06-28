#!/bin/bash
set -euo pipefail

kernel_cdn_list_versions() {
    local series="$1"
    curl -fsSL --connect-timeout 10 --max-time 45 "${KERNEL_CDN}/${series}/" \
        | grep -oE "linux-[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz" \
        | sed 's/linux-//;s/\.tar\.xz//' \
        | sort -Vu
}

kernel_version_to_series() {
    echo "v${1%%.*}.x"
}

kernel_tarball_url() {
    local ver="$1"
    echo "${KERNEL_CDN}/$(kernel_version_to_series "${ver}")/linux-${ver}.tar.xz"
}
