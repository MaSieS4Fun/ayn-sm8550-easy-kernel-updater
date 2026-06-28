#!/bin/bash
# Runtime gaming/scheduler diagnostics for AYN SM8550 (run on device under load).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: ./scripts/diagnose-gaming-perf.sh [PID]

Collects scheduler / cpufreq / EAS hints while a game or emulator is running.
If PID is omitted, prints system-wide CPU summary only.

Save output when comparing kernels (6.18.8 vs 6.18.18 vs 7.0.x):

  ./scripts/diagnose-gaming-perf.sh > /tmp/perf-6.18.8.txt
  # launch game, then:
  ./scripts/diagnose-gaming-perf.sh $(pgrep -n retroarch) >> /tmp/perf-6.18.8.txt

EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

echo "=== AYN SM8550 gaming perf snapshot ==="
echo "date: $(date -Iseconds)"
echo "kernel: $(uname -r)"
echo "cmdline: $(tr '\0' ' ' < /proc/cmdline)"
echo

echo "--- cpufreq governors ---"
for g in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
    [[ -f "${g}" ]] || continue
    echo "${g}: $(cat "${g}") max=$(cat "${g%/scaling_governor}/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo '?')"
done
echo

echo "--- kernel capacity (sched_energy) ---"
for c in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -f "${c}/cpu_capacity" ]] || continue
    echo "$(basename "${c}"): capacity=$(cat "${c}/cpu_capacity") cur=$(cat "${c}/cpufreq/scaling_cur_freq" 2>/dev/null || echo '?')"
done
if [[ -f /sys/devices/system/cpu/cpu0/cpu_capacity ]]; then
    c0="$(cat /sys/devices/system/cpu/cpu0/cpu_capacity)"
    if [[ "${c0}" -gt 400 ]]; then
        echo "  !! cpu0 capacity=${c0} — EAS likely broken at runtime (expect ~326 on A510)"
    fi
fi
echo

if [[ -f /sys/kernel/debug/sched/eas_stats ]]; then
    echo "--- eas_stats ---"
    cat /sys/kernel/debug/sched/eas_stats 2>/dev/null || true
    echo
fi

target_pid="${1:-}"
if [[ -n "${target_pid}" ]]; then
    if [[ ! -d "/proc/${target_pid}" ]]; then
        echo "PID ${target_pid} not found" >&2
        exit 1
    fi
    echo "--- process ${target_pid}: $(tr '\0' ' ' < "/proc/${target_pid}/cmdline") ---"
    grep -E 'Cpus_allowed|Cpus_allowed_list' "/proc/${target_pid}/status" || true
    echo
    echo "--- top threads by CPU (sample) ---"
    ps -L -p "${target_pid}" -o pid,tid,psr,pcpu,comm --sort=-pcpu 2>/dev/null | head -15 || true
    echo
fi

dtsi="${ROOT}/.cache/linux-"*/arch/arm64/boot/dts/qcom/sm8550.dtsi
if compgen -G "${dtsi}" > /dev/null; then
    # shellcheck source=/dev/null
    source "${ROOT}/lib/verify-eas.sh"
    echo "--- built tree EAS (last cached kernel source) ---"
    verify_eas_in_dtsi "$(ls -td ${ROOT}/.cache/linux-*/arch/arm64/boot/dts/qcom/sm8550.dtsi 2>/dev/null | head -1)" || true
fi

echo
echo "Suspect Armbian patches if EAS OK but perf bad (bisect in order):"
echo "  0102 / 0028  EAS capacities (Wuxilin)"
echo "  0122         interconnect QoS (GPU/CPU bandwidth)"
echo "  0154         OPP acd-level"
echo "  0200-0204    AYN common.dtsi + multi-board refactor"
echo "  0101         DDR/LLCC/L3 bandwidth scaling"
