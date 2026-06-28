#!/bin/bash
# Known-good 6.18.8 gaming baseline (config/golden.config)
set -euo pipefail

GOLDEN_CONFIG="${ROOT}/config/golden.config"

ensure_golden_config() {
    local src="" candidate
    [[ -f "${GOLDEN_CONFIG}" ]] && return 0

    for candidate in \
        /boot/config-6.18.8-edge-sm8550 \
        /boot/config-6.18.8-* \
    ; do
        [[ -f "${candidate}" ]] || continue
        src="${candidate}"
        break
    done

    if [[ -z "${src}" ]]; then
        echo "WARNING: config/golden.config missing." >&2
        echo "  Copy a known-good config: ./scripts/save-golden-config.sh /boot/config-*" >&2
        return 1
    fi

    mkdir -p "${ROOT}/config"
    cp -f "${src}" "${GOLDEN_CONFIG}"
    echo "==> Installed gaming baseline: ${GOLDEN_CONFIG} (from ${src})" >&2
}
