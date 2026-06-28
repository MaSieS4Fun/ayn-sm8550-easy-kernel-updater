#!/bin/bash
# Gaming-optimized kernel .config (baseline from verified 6.18.8 image)
set -euo pipefail

warn_config_source() {
    local base="$1"
    echo "==> Config base: ${base}" >&2
    case "${base}" in
        *"/config/golden.config")
            echo "  Gaming baseline (verified 6.18.8 perf + HDMI boot)" >&2
            ;;
        *"/.cache/linux-sm8550-edge.config")
            echo "  WARNING: Armbian defconfig fallback — not gaming-tuned." >&2
            ;;
        *)
            echo "  Custom KERNEL_CONFIG override" >&2
            ;;
    esac
}

apply_gaming_kconfig_overrides() {
    local src_dir="$1"
    local cfg="${src_dir}/.config"
    local sc="${src_dir}/scripts/config"

    [[ -f "${cfg}" ]] || return 0
    [[ -x "${sc}" ]] || return 0

    echo "==> Gaming kconfig tuning (all builds)" >&2

    "${sc}" --file "${cfg}" \
        --enable SCHED_SMT \
        --enable SCHED_MC \
        --enable SCHED_CLUSTER \
        --disable PSI \
        --enable MMC_SDHCI_MSM_DOWNSTREAM \
        --set-str CPU_FREQ_DEFAULT_GOV_PERFORMANCE \
        --disable CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
        --enable CPU_FREQ_GOV_PERFORMANCE \
        --enable ENERGY_MODEL \
        --enable CC_OPTIMIZE_FOR_PERFORMANCE \
        --disable CC_OPTIMIZE_FOR_SIZE 2>/dev/null || true

    # LT8912 HDMI bridge: built-in (=y) hangs early boot when dock HDMI is connected.
    "${sc}" --file "${cfg}" \
        --module DRM_LONTIUM_LT8912B 2>/dev/null || \
    "${sc}" --file "${cfg}" \
        --disable DRM_LONTIUM_LT8912B 2>/dev/null || true

    make -C "${src_dir}" ARCH=arm64 olddefconfig
}

apply_gaming_config_tweaks() {
    local src_dir="$1"
    [[ "${GAMING_TUNING:-1}" == "0" ]] && {
        echo "==> GAMING_TUNING=0 — skipping gaming overrides" >&2
        return 0
    }
    apply_gaming_kconfig_overrides "${src_dir}"
}
