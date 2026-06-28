#!/bin/bash
# Interactive menus (whiptail → dialog → plain text fallback)
set -euo pipefail

# Set by ui_select_* — do not use $(ui_select_*) (subshell breaks Armbian assoc arrays)
SELECTED_KERNEL_VER=""
SELECTED_DEVICE=""

ui_banner() {
    clear
    echo "============================================================"
    echo "  AYN SM8550 Kernel Update"
    echo "  Gaming-tuned builds (golden config + EAS + safe HDMI boot)"
    echo "============================================================"
    echo ""
}

_ui_cmd() {
    [[ "${UI:-}" == "plain" ]] && { echo plain; return; }
    [[ ! -t 0 || ! -t 1 ]] && { echo plain; return; }
    if command -v whiptail >/dev/null 2>&1; then echo whiptail
    elif command -v dialog >/dev/null 2>&1; then echo dialog
    else echo plain
    fi
}

check_build_deps() {
    local missing=()
    for cmd in curl make gcc bc bison flex patch python3; do
        command -v "${cmd}" >/dev/null || missing+=("${cmd}")
    done
    for pkg in libssl-dev libncurses-dev libelf-dev; do
        dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  sudo apt install build-essential libssl-dev libncurses-dev libelf-dev \\"
        echo "    flex bison bc curl patch initramfs-tools whiptail python3"
        return 1
    fi
    return 0
}

check_running_on_device() {
    if [[ ! -d /lib/firmware/qcom/sm8550 && ! -d /usr/lib/firmware/qcom/sm8550 ]]; then
        echo "WARNING: qcom/sm8550 firmware not found under /lib/firmware or /usr/lib/firmware."
        echo "Run this script on an AYN SM8550 device with firmware installed."
        echo ""
        read -r -p "Continue anyway? [y/N] " ans < /dev/tty
        [[ "${ans,,}" == "y" ]] || exit 1
    fi
}

ui_select_kernel() {
    local -a versions=()
    local series ver n pick

    SELECTED_KERNEL_VER=""
    n="${KERNEL_VERSIONS_PER_SERIES:-5}"
    echo "Supported (from Armbian): $(armbian_support_summary)" >&2
    echo "Querying kernel.org (may take 10-30 s)..." >&2
    for series in "${ARMBIAN_KERNEL_SERIES[@]}"; do
        echo "  -> ${series}.x (${ARMBIAN_SERIES_PATCH_SET[$series]}) ..." >&2
        while IFS= read -r ver; do
            [[ -n "${ver}" ]] && versions+=("${ver}")
        done < <(kernel_cdn_list_versions "v${series%%.*}.x" | grep "^${series}\\." | tail -"${n}")
    done
    echo "  -> done." >&2

    if [[ ${#versions[@]} -eq 0 ]]; then
        echo "Could not fetch versions from kernel.org" >&2
        return 1
    fi

    local -a unique=()
    while IFS= read -r ver; do unique+=("${ver}"); done < <(printf '%s\n' "${versions[@]}" | sort -Vu)

    ui_menu "Step 1/3 — Kernel" \
        "Latest compatible releases from kernel.org:" \
        "${unique[@]}" || return 1
    pick="${UI_MENU_RESULT}"

    if ! kernel_is_supported "${pick}"; then
        echo "linux-${pick} is not supported by current Armbian patch sets." >&2
        return 1
    fi

    SELECTED_KERNEL_VER="${pick}"
    echo "Selected kernel: linux-${pick}" >&2
    return 0
}

ui_select_device() {
    local pick

    SELECTED_DEVICE=""
    ui_menu "Step 2/3 — Device" \
        "Which DTB(s) to build:" \
        "ALL" \
        "AYN Odin 2" \
        "AYN Odin 2 Portal" \
        "AYN Odin 2 Mini" \
        "AYN Thor" || return 1
    pick="${UI_MENU_RESULT}"

    case "${pick}" in
        "ALL")               SELECTED_DEVICE="all" ;;
        "AYN Odin 2")        SELECTED_DEVICE="odin2" ;;
        "AYN Odin 2 Portal") SELECTED_DEVICE="portal" ;;
        "AYN Odin 2 Mini")   SELECTED_DEVICE="mini" ;;
        "AYN Thor")          SELECTED_DEVICE="thor" ;;
        *)                   SELECTED_DEVICE="${pick}" ;;
    esac
    echo "Selected device: ${SELECTED_DEVICE}" >&2
    return 0
}

ui_menu() {
    local title="$1" text="$2"
    shift 2
    local -a items=("$@")
    local ui n i choice

    UI_MENU_RESULT=""
    ui="$(_ui_cmd)"

    if [[ "${ui}" != "plain" ]]; then
        local -a args=()
        for i in "${!items[@]}"; do
            args+=("$((i+1))" "${items[$i]}")
        done
        if [[ "${ui}" == "whiptail" ]]; then
            choice="$(whiptail --title "${title}" --menu "${text}" 20 70 12 "${args[@]}" 3>&1 1>&2 2>&3)" || return 1
        else
            choice="$(dialog --stdout --title "${title}" --menu "${text}" 20 70 12 "${args[@]}")" || return 1
        fi
        UI_MENU_RESULT="${items[$((choice-1))]}"
        return 0
    fi

    {
        echo ""
        echo "-- ${title} --"
        echo "${text}"
        echo ""
        for i in "${!items[@]}"; do
            echo "  $((i+1))) ${items[$i]}"
        done
        echo "  0) Cancel"
        echo ""
    } >&2

    if [[ -r /dev/tty ]]; then
        read -r -p "Enter option number and press Enter: " n < /dev/tty
    else
        read -r -p "Enter option number and press Enter: " n
    fi
    [[ "${n}" == "0" ]] && return 1
    if ! [[ "${n}" =~ ^[0-9]+$ && "${n}" -ge 1 && "${n}" -le ${#items[@]} ]]; then
        echo "Invalid option: '${n}'. Use a number from 1 to ${#items[@]}." >&2
        return 1
    fi
    UI_MENU_RESULT="${items[$((n-1))]}"
    return 0
}

ui_confirm_build() {
    local ver="$1" device="$2" patch_set="$3"
    local dev_label
    case "${device}" in
        all) dev_label="ALL (Odin2 + Portal + Mini + Thor)" ;;
        odin2) dev_label="AYN Odin 2" ;;
        portal) dev_label="AYN Odin 2 Portal" ;;
        mini) dev_label="AYN Odin 2 Mini" ;;
        thor) dev_label="AYN Thor" ;;
        *) dev_label="${device}" ;;
    esac

    local msg profile_line=""
    if [[ -n "${PERF_PROFILE:-}" && "${PERF_PROFILE}" != "full" ]]; then
        profile_line="Perf:       ${PERF_PROFILE} — $(perf_profile_description "${PERF_PROFILE}")
"
    fi
    msg="Kernel:     linux-${ver}
Patches:    ${patch_set}
Config:     gaming baseline (golden 6.18.8 + tuning)
Initramfs:  ${INITRAMFS_PROFILE:-minimal} (HDMI-at-boot safe)
${profile_line}Device:     ${dev_label}
Jobs:       ${JOBS}
Output:     ${OUTPUT_DIR}/${ver}${KERNEL_LOCALVERSION}/

Supported:  $(armbian_support_summary)

Firmware:   $(firmware_summary_line)
Nothing will be installed to /boot."

    local ui="$(_ui_cmd)"
    if [[ "${ui}" == "whiptail" ]]; then
        whiptail --title "Confirm build" --yesno "${msg}" 16 70
        return $?
    elif [[ "${ui}" == "dialog" ]]; then
        dialog --title "Confirm build" --yesno "${msg}" 16 70
        return $?
    fi

    {
        echo ""
        echo "-- Step 3/3 — Confirm --"
        echo ""
        echo "${msg}"
        echo ""
    } >&2
    read -r -p "Build now? Type y and press Enter: " ans < /dev/tty
    [[ "${ans,,}" == "y" ]]
}

ui_build_complete() {
    local out="$1"
    echo ""
    echo "============================================================"
    echo "  BUILD COMPLETE"
    echo "============================================================"
    echo ""
    echo "  Output: ${out}/"
    echo ""
    echo "  boot/       Image, initrd, DTBs, LinuxLoader.cfg, uInitrd"
    echo "  modules/    lib/modules/<version>/ (full tree)"
    echo "  firmware/   ROCKNIX-trimmed set (linux-firmware + AYN overlays)"
    echo ""
    echo "  See MANIFEST.txt and INSTALL.txt. Install with ./update.sh"
    echo ""
    read -r -p "Press Enter to exit..." _ < /dev/tty
}
