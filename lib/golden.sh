#!/bin/bash
# Known-good 6.18.8 gaming baseline (config + optional import sources)
set -euo pipefail

GOLDEN_CONFIG="${ROOT}/config/golden.config"

ensure_golden_config() {
    local src="" candidate
    [[ -f "${GOLDEN_CONFIG}" ]] && return 0

    for candidate in \
        "${ROOT}/../kernel-6.18.8-rendimineto/boot/config-6.18.8-edge-sm8550" \
        "/home/odin2/Projects/kernel-6.18.8-rendimineto/boot/config-6.18.8-edge-sm8550" \
        /boot/config-6.18.8-edge-sm8550 \
        /boot/config-6.18.8-* \
    ; do
        [[ -f "${candidate}" ]] || continue
        src="${candidate}"
        break
    done

    if [[ -z "${src}" ]]; then
        echo "WARNING: config/golden.config missing and no 6.18.8 reference found." >&2
        echo "  Gaming overrides still apply, but base .config may be suboptimal." >&2
        echo "  Place a good config at: ${GOLDEN_CONFIG}" >&2
        return 1
    fi

    mkdir -p "${ROOT}/config"
    cp -f "${src}" "${GOLDEN_CONFIG}"
    echo "==> Installed gaming baseline: ${GOLDEN_CONFIG} (from ${src})" >&2
}
