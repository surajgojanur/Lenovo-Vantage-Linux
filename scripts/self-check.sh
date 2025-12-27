#!/bin/bash

set -euo pipefail

STATUS=0
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
VPC_PATH=""
PARTIAL=0

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

check_cmd() {
    local cmd="$1"
    local label="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        log OK "Found $label ($cmd)"
    else
        log FAIL "Missing $label ($cmd)"
        STATUS=1
    fi
}

check_vpc() {
    VPC_PATH=$(ls -d /sys/bus/platform/devices/VPC2004:* 2>/dev/null | head -n1 || true)
    if [ -n "$VPC_PATH" ]; then
        log OK "Found VPC platform device: $VPC_PATH"
    else
        log FAIL "VPC2004 platform device not found (required for hardware controls)."
        STATUS=1
    fi
}

check_session() {
    if [ "$SESSION_TYPE" = "x11" ]; then
        log OK "Session type: x11"
    elif [ "$SESSION_TYPE" = "wayland" ]; then
        log WARN "Session type: wayland (xinput-based features disabled; partial support)"
        PARTIAL=1
    else
        log FAIL "Session type unknown ('$SESSION_TYPE')"
        STATUS=1
    fi
}

check_networkmanager() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet NetworkManager; then
            log OK "NetworkManager service active"
        else
            log FAIL "NetworkManager service not active"
            STATUS=1
        fi
    else
        log WARN "systemctl not available; cannot verify NetworkManager service"
    fi
}

main() {
    log INFO "Running Lenovo Vantage self-check"

    check_cmd zenity "Zenity UI"
    check_cmd pkexec "PolicyKit exec"
    check_cmd xinput "X input"
    check_cmd nmcli "NetworkManager CLI"
    check_cmd pactl "PulseAudio/PipeWire pactl"
    check_cmd lsmod "Kernel module lister"

    check_session
    check_vpc
    check_networkmanager

    if [ "$STATUS" -eq 0 ]; then
        if [ "$PARTIAL" -eq 1 ]; then
            log INFO "Self-check status: PARTIAL SUPPORT (Wayland detected; xinput features disabled)."
        else
            log INFO "Self-check passed."
        fi
    else
        log INFO "Self-check completed with issues."
    fi

    exit "$STATUS"
}

main "$@"
