#!/bin/bash
# EAS gaming fix verification (Xilin Wu / AYN Odin2 measurements)
set -euo pipefail

verify_eas_in_dtsi() {
    local dtsi="$1"
    [[ -f "${dtsi}" ]] || { echo "EAS: missing ${dtsi}" >&2; return 1; }

    local -a expect=(
        "cpu@0|326"
        "cpu@100|326"
        "cpu@200|326"
        "cpu@300|693"
        "cpu@700|1024"
    )
    local entry cpu cap val block
    local failed=0

    echo "==> EAS check (gaming) — sm8550.dtsi CPU capacities" >&2

    for entry in "${expect[@]}"; do
        cpu="${entry%%|*}"
        cap="${entry#*|}"
        block="$(awk -v cpu="${cpu}" '
            # Labels vary: "CPU0: cpu@0 {" not "cpu: cpu@0 {"
            $0 ~ cpu "[[:space:]]*\\{" { found=1; next }
            found && /capacity-dmips-mhz/ {
                gsub(/[^0-9]/, "", $0); print; exit
            }
            found && /^[[:space:]]*}[[:space:]]*$/ { exit }
        ' "${dtsi}")"
        if [[ "${block}" == "${cap}" ]]; then
            echo "  OK  ${cpu} capacity=${cap}" >&2
        else
            echo "  !!  ${cpu} capacity=${block:-missing} (expected ${cap})" >&2
            failed=1
        fi
    done

    if [[ "${failed}" -eq 0 ]]; then
        echo "  EAS DT values match Wuxilin gaming calibration" >&2
        return 0
    fi

    echo "  Risk of ~40-50% gaming loss if A510 capacity stays at Qualcomm defaults (1024)." >&2
    echo "  Check patch 0102 (6.18) / 0028 (7.0) applied and was not overwritten later." >&2
    return 1
}
