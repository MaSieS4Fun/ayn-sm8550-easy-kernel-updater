#!/bin/bash
# Compare known-good 6.18.8 backup vs script-built configs and boot artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOLD="${GOLDEN_DIR:-/home/odin2/Projects/kernel-6.18.8-rendimineto}"
REPORT="${ROOT}/output/golden-analysis.txt"
mkdir -p "${ROOT}/output" "${ROOT}/config"

{
    echo "=== Golden kernel analysis ==="
    echo "date: $(date -Iseconds)"
    echo "golden: ${GOLD}"
    echo

    echo "--- Golden tree ---"
    find "${GOLD}" -type f 2>/dev/null | sort | while read -r f; do
        printf '%10s  %s\n' "$(stat -c '%s' "${f}" 2>/dev/null || echo '?')" "${f#${GOLD}/}"
    done
    echo

    GOLD_CFG="${GOLD}/boot/config-6.18.8-edge-sm8550"
    if [[ -f "${GOLD_CFG}" ]]; then
        cp -f "${GOLD_CFG}" "${ROOT}/config/golden.config"
        echo "Saved ${ROOT}/config/golden.config"
        echo
    else
        echo "MISSING: ${GOLD_CFG}" >&2
    fi

    diff_cfg() {
        local a="$1" b="$2" label="$3"
        [[ -f "${a}" && -f "${b}" ]] || { echo "skip ${label}: missing file"; return; }
        echo "--- CONFIG DIFF: golden vs ${label} ---"
        diff -u <(grep -E '^CONFIG_(SCHED|ENERGY|CPU_FREQ|HZ|NO_HZ|LOCALVERSION|MSM|DRM|KGSL|ADRENO|INTERCONNECT|PM_|CPUIDLE)' "${a}" | sort) \
                <(grep -E '^CONFIG_(SCHED|ENERGY|CPU_FREQ|HZ|NO_HZ|LOCALVERSION|MSM|DRM|KGSL|ADRENO|INTERCONNECT|PM_|CPUIDLE)' "${b}" | sort) || true
        echo
        echo "--- CONFIG DIFF stats (all symbols) ---"
        diff -u "${a}" "${b}" | diffstat | tail -3 || true
        echo
    }

    SLOW_CFG="${ROOT}/output/7.0.14-edge-sm8550/boot/config-7.0.14-edge-sm8550"
    ARMB_CFG="${ROOT}/.cache/linux-sm8550-edge.config"
    [[ -f "${GOLD_CFG}" ]] && diff_cfg "${GOLD_CFG}" "${SLOW_CFG}" "script 7.0.14"
    [[ -f "${GOLD_CFG}" && -f "${ARMB_CFG}" ]] && diff_cfg "${GOLD_CFG}" "${ARMB_CFG}" "armbian defconfig"

    echo "--- Golden cmdline (LinuxLoader.cfg) ---"
    grep -E '^(cmdline|initrd|devicetree|Image)' "${GOLD}/boot/LinuxLoader.cfg" 2>/dev/null || true
    echo

    for dtb in "${GOLD}/boot/"*.dtb; do
        [[ -f "${dtb}" ]] || continue
        echo "--- DTB: $(basename "${dtb}") size=$(stat -c '%s' "${dtb}") ---"
        if command -v fdtdump >/dev/null 2>&1; then
            fdtdump "${dtb}" 2>/dev/null | grep -E 'capacity-dmips|dynamic-power-coefficient' | head -20 || true
        elif command -v strings >/dev/null 2>&1; then
            strings "${dtb}" | grep -E 'capacity|cpu@' | head -20 || true
        fi
        echo
    done

    GOLD_INITRD="${GOLD}/boot/initrd.img-6.18.8-edge-sm8550"
    SLOW_INITRD="${ROOT}/output/7.0.14-edge-sm8550/boot/initrd.img-7.0.14-edge-sm8550"
    for initrd in "${GOLD_INITRD}" "${SLOW_INITRD}"; do
        [[ -f "${initrd}" ]] || continue
        echo "--- initrd modules: $(basename "${initrd}") ---"
        lsinitramfs "${initrd}" 2>/dev/null | grep -E 'lib/modules.*\.ko' | grep -iE 'drm|msm|panel|hdmi|lt8912|kgsl|gpucpower' | sort -u || \
            echo "(lsinitramfs unavailable or no display modules listed)"
        echo
    done

    GOLD_IMG="${GOLD}/boot/Image"
    SLOW_IMG="${ROOT}/output/7.0.14-edge-sm8550/boot/Image"
    for img in "${GOLD_IMG}" "${SLOW_IMG}"; do
        [[ -f "${img}" ]] || continue
        echo "--- $(basename "$(dirname "${img}")")/Image ---"
        file "${img}" 2>/dev/null || true
        stat -c 'size=%s mtime=%y' "${img}" 2>/dev/null || true
    done
} | tee "${REPORT}"

echo "Report: ${REPORT}" >&2
