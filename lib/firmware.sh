#!/bin/bash
set -euo pipefail

# Set by prepare_firmware / copy_system_firmware
FIRMWARE_LINUX_VERSION=""
FIRMWARE_MANIFEST=""
FIRMWARE_POLICY_USED=""
FIRMWARE_FILE_COUNT=0
FIRMWARE_SYSTEM_ROOT=""

_firmware_manifest() {
    if [[ -n "${FIRMWARE_MANIFEST:-}" && -f "${FIRMWARE_MANIFEST}" ]]; then
        echo "${FIRMWARE_MANIFEST}"
        return 0
    fi
    echo "${ROOT}/config/firmware-sm8550.dat"
}

_system_firmware_root() {
    local p
    for p in /lib/firmware /usr/lib/firmware; do
        if [[ -d "${p}/qcom/sm8550" || -d "${p}/qcom" ]]; then
            echo "${p}"
            return 0
        fi
    done
    echo "/lib/firmware"
}

_firmware_pattern_files() {
    local root="$1" pattern="$2"
    [[ -d "${root}" ]] || return 0
    if [[ -f "${root}/${pattern}" ]]; then
        echo "${pattern}"
        return 0
    fi
    (cd "${root}" && eval "find ${pattern} -type f 2>/dev/null" || true) | sort -u
}

_parse_manifest_entry() {
    # Usage: _parse_manifest_entry "$line" -> sets MANIFEST_OPTIONAL, MANIFEST_PREFER_SYSTEM, MANIFEST_PATTERN
    local raw="$1"
    MANIFEST_OPTIONAL=0
    MANIFEST_PREFER_SYSTEM=0
    MANIFEST_PATTERN="${raw}"

    while [[ "${MANIFEST_PATTERN}" == \?* ]]; do
        MANIFEST_OPTIONAL=1
        MANIFEST_PATTERN="${MANIFEST_PATTERN#?}"
    done
    MANIFEST_PATTERN="${MANIFEST_PATTERN#"${MANIFEST_PATTERN%%[![:space:]]*}"}"

    if [[ "${MANIFEST_PATTERN}" == @system* ]]; then
        MANIFEST_PREFER_SYSTEM=1
        MANIFEST_PATTERN="${MANIFEST_PATTERN#@system}"
        MANIFEST_PATTERN="${MANIFEST_PATTERN#"${MANIFEST_PATTERN%%[![:space:]]*}"}"
    fi
}

_install_firmware_pattern() {
    local linux_src="$1" system_src="$2" dest="$3" pattern="$4" prefer_system="${5:-0}"
    local -a files=()
    local f src n=0

    mapfile -t files < <(
        {
            _firmware_pattern_files "${linux_src}" "${pattern}"
            _firmware_pattern_files "${system_src}" "${pattern}"
        } | sort -u
    )

    for f in "${files[@]}"; do
        [[ -n "${f}" ]] || continue
        [[ -f "${dest}/${f}" ]] && continue
        if [[ "${prefer_system}" == "1" ]]; then
            if [[ -f "${system_src}/${f}" ]]; then
                src="${system_src}/${f}"
            elif [[ -f "${linux_src}/${f}" ]]; then
                src="${linux_src}/${f}"
            else
                continue
            fi
        else
            if [[ -f "${linux_src}/${f}" ]]; then
                src="${linux_src}/${f}"
            elif [[ -f "${system_src}/${f}" ]]; then
                src="${system_src}/${f}"
            else
                continue
            fi
        fi
        mkdir -p "${dest}/$(dirname "${f}")"
        cp -L "${src}" "${dest}/${f}"
        n=$((n + 1))
    done
    echo "${n}"
}

_firmware_post_install() {
    local fw_out="$1"
    local sm8550="${fw_out}/qcom/sm8550"
    local odin2_tplg="${sm8550}/AYN-Odin2-tplg.bin"
    local thor_tplg="${sm8550}/AYN-Thor-tplg.bin"

    [[ -d "${sm8550}" ]] || return 0

    if [[ -f "${odin2_tplg}" && ! -e "${thor_tplg}" ]]; then
        ln -sf AYN-Odin2-tplg.bin "${thor_tplg}"
        echo "  ~ AYN-Thor-tplg.bin -> AYN-Odin2-tplg.bin (ROCKNIX compat)" >&2
    fi
}

ensure_linux_firmware_source() {
    local version="${LINUX_FIRMWARE_VERSION}"
    local sha256="${LINUX_FIRMWARE_SHA256:-}"
    local url="${KERNEL_FIRMWARE_CDN}/linux-firmware-${version}.tar.xz"
    local tar="${CACHE_DIR}/linux-firmware-${version}.tar.xz"
    local dest="${CACHE_DIR}/linux-firmware-${version}"

    if [[ -f "${dest}/WHENCE" || -f "${dest}/copy-firmware.sh" ]]; then
        echo "${dest}"
        return 0
    fi

    echo "==> Downloading linux-firmware-${version}" >&2
    if [[ ! -f "${tar}" ]]; then
        curl -fL --progress-bar --max-time 900 -o "${tar}.partial" "${url}"
        mv "${tar}.partial" "${tar}"
    fi

    if [[ -n "${sha256}" ]]; then
        echo "${sha256}  ${tar}" | sha256sum -c - >&2
    fi

    rm -rf "${dest}"
    echo "==> Extracting linux-firmware-${version}" >&2
    tar -xJf "${tar}" -C "${CACHE_DIR}"
    echo "${dest}"
}

copy_system_firmware() {
    local out_dir="$1"
    local fw_out="${out_dir}/firmware"
    local system_src
    system_src="$(_system_firmware_root)"
    FIRMWARE_SYSTEM_ROOT="${system_src}"

    rm -rf "${fw_out}"
    mkdir -p "${fw_out}"

    FIRMWARE_POLICY_USED="system"
    FIRMWARE_LINUX_VERSION=""
    FIRMWARE_MANIFEST="(system paths)"

    echo "==> Copying system firmware from ${system_src}/" >&2

    local path
    for path in \
        qcom/sm8550 \
        qcom/a740_sqe.fw \
        qcom/gmu_gen70200.bin \
        qcom/vpu \
        qcom/a740_zap.mbn \
        ath12k/WCN7850 \
        qca \
    ; do
        if [[ -e "${system_src}/${path}" ]]; then
            mkdir -p "${fw_out}/$(dirname "${path}")"
            cp -a "${system_src}/${path}" "${fw_out}/${path}"
            echo "  + ${path}" >&2
        fi
    done

    FIRMWARE_FILE_COUNT="$(find "${fw_out}" -type f | wc -l | tr -d ' ')"
    _write_firmware_info "${out_dir}"
}

prepare_firmware() {
    local out_dir="$1"
    local fw_out="${out_dir}/firmware"
    local manifest
    manifest="$(_firmware_manifest)"
    local policy="${FIRMWARE_POLICY:-rocknix}"
    local system_src

    system_src="$(_system_firmware_root)"
    FIRMWARE_SYSTEM_ROOT="${system_src}"
    FIRMWARE_MANIFEST="${manifest}"

    if [[ "${policy}" == "system" ]]; then
        copy_system_firmware "${out_dir}"
        return 0
    fi

    rm -rf "${fw_out}"
    mkdir -p "${fw_out}"

    local linux_src
    linux_src="$(ensure_linux_firmware_source)"
    FIRMWARE_LINUX_VERSION="${LINUX_FIRMWARE_VERSION}"
    FIRMWARE_POLICY_USED="rocknix"

    echo "==> Preparing firmware (ROCKNIX manifest + AYN overlays)" >&2
    echo "    linux-firmware: ${LINUX_FIRMWARE_VERSION}" >&2
    echo "    system root:    ${system_src}" >&2
    echo "    manifest:       $(basename "${manifest}")" >&2

    [[ -f "${manifest}" ]] || {
        echo "Missing firmware manifest: ${manifest}" >&2
        return 1
    }

    local line pattern n total=0 optional=0 prefer_system=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" =~ ^[[:space:]] ]] && continue

        _parse_manifest_entry "${line}"
        optional="${MANIFEST_OPTIONAL}"
        prefer_system="${MANIFEST_PREFER_SYSTEM}"
        pattern="${MANIFEST_PATTERN}"

        n="$(_install_firmware_pattern "${linux_src}" "${system_src}" "${fw_out}" "${pattern}" "${prefer_system}")"
        if [[ "${n}" -gt 0 ]]; then
            echo "  + ${pattern} (${n} files)" >&2
            total=$((total + n))
        elif [[ "${optional}" == "1" ]]; then
            echo "  - ${pattern} (optional, skipped)" >&2
        else
            echo "  ! no files matched: ${pattern}" >&2
            if [[ "${FIRMWARE_STRICT:-1}" == "1" ]]; then
                echo "ERROR: required firmware pattern missing: ${pattern}" >&2
                echo "       Check ${system_src} or set FIRMWARE_STRICT=0" >&2
                return 1
            fi
        fi
    done < "${manifest}"

    _firmware_post_install "${fw_out}"

    FIRMWARE_FILE_COUNT="$(find "${fw_out}" -type f | wc -l | tr -d ' ')"
    echo "  total: ${FIRMWARE_FILE_COUNT} files ($(du -sh "${fw_out}" | cut -f1))" >&2
    _write_firmware_info "${out_dir}"
}

_write_firmware_info() {
    local out_dir="$1"
    local info="${out_dir}/firmware/.firmware-info"
    cat > "${info}" <<EOF
policy=${FIRMWARE_POLICY_USED}
linux_firmware_version=${FIRMWARE_LINUX_VERSION:-none}
system_root=${FIRMWARE_SYSTEM_ROOT:-/lib/firmware}
manifest=${FIRMWARE_MANIFEST}
file_count=${FIRMWARE_FILE_COUNT}
date=$(date -Iseconds)
EOF
}

firmware_summary_line() {
    if [[ "${FIRMWARE_POLICY:-rocknix}" == "system" ]]; then
        echo "/lib/firmware (system copy)"
    else
        echo "ROCKNIX manifest + linux-firmware-${LINUX_FIRMWARE_VERSION:-?}"
    fi
}
