#!/bin/bash
# Discover supported kernel series from Armbian build repo (remote).
# When Armbian adds sm8550-7.1 patches, this script picks them up automatically.
set -euo pipefail

ARMBIAN_FAMILY_CONF="${ARMBIAN_PATCH_RAW}/config/sources/families/sm8550.conf"
ARMBIAN_ARCHIVE_API="https://api.github.com/repos/armbian/build/contents/patch/kernel/archive"
ARMBIAN_SUPPORT_CACHE="${CACHE_DIR}/armbian-support.env"
ARMBIAN_SUPPORT_TTL="${ARMBIAN_SUPPORT_TTL:-43200}"  # 12 hours

# Populated by refresh_armbian_support()
declare -ga ARMBIAN_KERNEL_SERIES=()
declare -gA ARMBIAN_SERIES_PATCH_SET=()
declare -g ARMBIAN_EDGE_SERIES=""

# Fallback if GitHub is unreachable and no cache exists
FALLBACK_KERNEL_SERIES=(7.0)
declare -gA FALLBACK_SERIES_PATCH_SET=( ["7.0"]="sm8550-7.0" )

_load_support_from_cache() {
    [[ -f "${ARMBIAN_SUPPORT_CACHE}" ]] || return 1
    # shellcheck source=/dev/null
    source "${ARMBIAN_SUPPORT_CACHE}"
    [[ ${#ARMBIAN_KERNEL_SERIES[@]} -gt 0 ]]
}

_save_support_cache() {
    {
        echo "# Armbian SM8550 support — fetched $(date -Iseconds)"
        echo "ARMBIAN_EDGE_SERIES=\"${ARMBIAN_EDGE_SERIES}\""
        echo -n "ARMBIAN_KERNEL_SERIES=("
        printf '%s ' "${ARMBIAN_KERNEL_SERIES[@]}"
        echo ")"
        local s
        for s in "${ARMBIAN_KERNEL_SERIES[@]}"; do
            echo "ARMBIAN_SERIES_PATCH_SET_${s//./_}=\"${ARMBIAN_SERIES_PATCH_SET[$s]}\""
        done
    } > "${ARMBIAN_SUPPORT_CACHE}.tmp"
    mv "${ARMBIAN_SUPPORT_CACHE}.tmp" "${ARMBIAN_SUPPORT_CACHE}"
}

_fetch_patch_sets_from_github() {
    curl -fsSL --connect-timeout 15 --max-time 45 "${ARMBIAN_ARCHIVE_API}" \
        | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
for item in sorted(data, key=lambda x: x['name']):
    m = re.match(r'^sm8550-(\d+\.\d+)\$', item['name'])
    if m:
        print(f\"{m.group(1)} {item['name']}\")
"
}

_fetch_edge_series_from_conf() {
    curl -fsSL --connect-timeout 15 --max-time 30 "${ARMBIAN_FAMILY_CONF}" 2>/dev/null \
        | awk '
            /^\s*edge\)/ { in_edge=1; next }
            in_edge && /KERNEL_MAJOR_MINOR=/ {
                gsub(/.*"/, ""); gsub(/".*/, ""); print; exit
            }
            in_edge && /^[[:space:]]*[a-z]/ && !/^\s+/ { in_edge=0 }
        ' || true
}

refresh_armbian_support() {
    local cache_age=999999
    if [[ -f "${ARMBIAN_SUPPORT_CACHE}" ]]; then
        cache_age=$(( $(date +%s) - $(stat -c %Y "${ARMBIAN_SUPPORT_CACHE}" 2>/dev/null || echo 0) ))
    fi

    if [[ "${cache_age}" -lt "${ARMBIAN_SUPPORT_TTL}" ]] && _load_support_from_cache; then
        # Rebuild associative array from sourced variables
        _rebuild_patch_set_map_from_cache_vars
        return 0
    fi

    echo "==> Checking Armbian for supported SM8550 kernel series..." >&2

    local -a series=()
    local -a patch_sets=()
    local line mm ps edge

    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        mm="${line%% *}"
        ps="${line#* }"
        series+=("${mm}")
        patch_sets+=("${ps}")
    done < <(_fetch_patch_sets_from_github) || {
        echo "WARNING: could not reach Armbian on GitHub." >&2
        _load_support_from_cache && return 0
        _use_fallback_support
        return 0
    }

    if [[ ${#series[@]} -eq 0 ]]; then
        echo "WARNING: no sm8550-* patch sets found on Armbian." >&2
        _load_support_from_cache && return 0
        _use_fallback_support
        return 0
    fi

    ARMBIAN_KERNEL_SERIES=()
    ARMBIAN_SERIES_PATCH_SET=()

    local i
    for i in "${!series[@]}"; do
        ARMBIAN_SERIES_PATCH_SET["${series[$i]}"]="${patch_sets[$i]}"
    done

    # Newest series first (7.1 before 7.0)
    readarray -t ARMBIAN_KERNEL_SERIES < <(printf '%s\n' "${series[@]}" | sort -Vr)

    edge="$(_fetch_edge_series_from_conf)"
    ARMBIAN_EDGE_SERIES="${edge:-${ARMBIAN_KERNEL_SERIES[0]}}"

    _save_support_cache
    echo "  Supported series: ${ARMBIAN_KERNEL_SERIES[*]} (Armbian edge: ${ARMBIAN_EDGE_SERIES}.x)" >&2
}

_rebuild_patch_set_map_from_cache_vars() {
    ARMBIAN_SERIES_PATCH_SET=()
    local s key
    for s in "${ARMBIAN_KERNEL_SERIES[@]}"; do
        key="ARMBIAN_SERIES_PATCH_SET_${s//./_}"
        ARMBIAN_SERIES_PATCH_SET["${s}"]="${!key:-sm8550-${s}}"
    done
}

_use_fallback_support() {
    ARMBIAN_KERNEL_SERIES=("${FALLBACK_KERNEL_SERIES[@]}")
    ARMBIAN_SERIES_PATCH_SET=()
    local s
    for s in "${FALLBACK_KERNEL_SERIES[@]}"; do
        ARMBIAN_SERIES_PATCH_SET["${s}"]="${FALLBACK_SERIES_PATCH_SET[$s]}"
    done
    ARMBIAN_EDGE_SERIES="${FALLBACK_KERNEL_SERIES[0]}"
    echo "  Using fallback: ${ARMBIAN_KERNEL_SERIES[*]}" >&2
}

patch_set_for_version() {
    local ver="$1"
    local mm="${ver%.*}"  # 7.0.13 -> 7.0, 6.18.36 -> 6.18
    local ps="${ARMBIAN_SERIES_PATCH_SET[$mm]:-}"

    if [[ -n "${ps}" ]]; then
        echo "${ps}"
        return 0
    fi

    echo "No Armbian patch set for linux-${ver} (series ${mm}.x)." >&2
    echo "Supported series: ${ARMBIAN_KERNEL_SERIES[*]:-unknown}" >&2
    echo "Run again after Armbian publishes sm8550-${mm} patches." >&2
    return 1
}

kernel_is_supported() {
    patch_set_for_version "$1" >/dev/null 2>&1
}

armbian_support_summary() {
    local s parts=()
    for s in "${ARMBIAN_KERNEL_SERIES[@]}"; do
        parts+=("${s}.x (${ARMBIAN_SERIES_PATCH_SET[$s]})")
    done
    local IFS=', '
    echo "${parts[*]}"
}
