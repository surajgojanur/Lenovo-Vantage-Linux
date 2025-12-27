#!/bin/bash

set -o pipefail

VPC_PATH=""
TOUCHPAD_ID=""
SESSION_TYPE="unknown"
FEATURE_TOUCHPAD=true
FEATURE_XINPUT=true

APP_TITLE="Lenovo Vantage (Linux)"
APP_ICON_SYSTEM="/usr/share/icons/hicolor/scalable/apps/vantage.png"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ICON_FALLBACK="$SCRIPT_DIR/icon.png"
APP_ICON="$APP_ICON_SYSTEM"
[ -f "$APP_ICON_FALLBACK" ] && APP_ICON="$APP_ICON_FALLBACK"

ENABLE_FAN_MODE=1

SUBMENU_ON="Enable"
SUBMENU_OFF="Disable"

warn() {
    zenity --warning --window-icon="$APP_ICON" --title="$APP_TITLE" --width=400 --text="$1"
}

error() {
    zenity --error --window-icon="$APP_ICON" --title="$APP_TITLE" --width=420 --text="$1"
}

info() {
    zenity --info --window-icon="$APP_ICON" --title="$APP_TITLE" --width=420 --text="$1"
}

confirm_action() {
    local title="$1"
    local body="$2"
    zenity --question --window-icon="$APP_ICON" --title="$title" --width=420 --text="$body"
}

resolve_vpc_path() {
    ls -d /sys/bus/platform/devices/VPC2004:* 2>/dev/null | head -n1
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Missing dependency: $cmd"
        exit 1
    fi
}

require_environment() {
    if [ "$SESSION_TYPE" = "wayland" ]; then
        FEATURE_TOUCHPAD=false
        FEATURE_XINPUT=false
    elif [ "$SESSION_TYPE" = "x11" ]; then
        FEATURE_TOUCHPAD=true
        FEATURE_XINPUT=true
    else
        FEATURE_TOUCHPAD=false
        FEATURE_XINPUT=false
    fi
}

detect_session() {
    if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        SESSION_TYPE="wayland"
    elif [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
        SESSION_TYPE="x11"
    else
        SESSION_TYPE="unknown"
    fi
}

get_touchpad_id() {
    xinput list | grep -i "Touchpad" | head -n1 | cut -d '=' -f2 | awk '{print $1}'
}

get_conservation_mode_status() {
    awk '{print ($1 == "1") ? "On" : "Off"}' "$VPC_PATH/conservation_mode"
}

get_usb_charging_status() {
    awk '{print ($1 == "1") ? "On" : "Off"}' "$VPC_PATH/usb_charging"
}

get_fan_mode_status() {
    awk '{
        if ($1 == "133" || $1 == "0") print "Super Silent";
        else if ($1 == "1") print "Standard";
        else if ($1 == "2") print "Dust Cleaning";
        else if ($1 == "4") print "Efficient Thermal Dissipation";
    }' "$VPC_PATH/fan_mode"
}

get_fn_lock_status() {
    awk '{print ($1 == "1") ? "Off" : "On"}' "$VPC_PATH/fn_lock"
}

get_camera_status() {
    lsmod | grep -q 'uvcvideo' && echo "On" || echo "Off"
}

get_microphone_status() {
    pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print ($2 == "yes") ? "Muted" : "Active"}'
}

get_touchpad_status() {
    local tp_id="$1"
    xinput --list-props "$tp_id" | grep "Device Enabled" | cut -d ':' -f2 | awk '{print ($1 == "1") ? "On" : "Off"}'
}

get_wifi_status() {
    nmcli radio wifi | awk '{print ($1 == "enabled") ? "On" : "Off"}'
}

show_submenu() {
    local title="$1"
    local status="$2"
    shift 2
    zenity --list --window-icon="$APP_ICON" --title="$title" --text "Current: $status" --column "Option" "$@"
}

show_submenu_on_off() {
    show_submenu "$@" "$SUBMENU_ON" "$SUBMENU_OFF"
}

apply_sysfs_value() {
    local path="$1"
    local value="$2"
    printf '%s\n' "$value" | pkexec tee "$path" >/dev/null
}

main_menu() {
    local options=()

    [ -f "$VPC_PATH/conservation_mode" ] && options+=("Conservation Mode" "$(get_conservation_mode_status)")
    [ -f "$VPC_PATH/usb_charging" ] && options+=("Always-On USB" "$(get_usb_charging_status)")
    [ "$ENABLE_FAN_MODE" -eq 1 ] && [ -f "$VPC_PATH/fan_mode" ] && options+=("Fan Mode" "$(get_fan_mode_status)")
    [ -f "$VPC_PATH/fn_lock" ] && options+=("FN Lock" "$(get_fn_lock_status)")
    modinfo -n uvcvideo >/dev/null 2>&1 && options+=("Camera" "$(get_camera_status)")
    command -v pactl >/dev/null 2>&1 && options+=("Microphone" "$(get_microphone_status)")
    if [ "$FEATURE_TOUCHPAD" = true ] && [ -n "$TOUCHPAD_ID" ]; then
        options+=("Touchpad" "$(get_touchpad_status "$TOUCHPAD_ID")")
    fi
    command -v nmcli >/dev/null 2>&1 && options+=("WiFi" "$(get_wifi_status)")

    if [ ${#options[@]} -eq 0 ]; then
        error "No supported controls detected on this system. Ensure compatible Lenovo hardware is present."
        exit 1
    fi

    zenity --list \
        --window-icon="$APP_ICON" \
        --title="$APP_TITLE" \
        --text "Select a function. Actions requiring privileges will ask for confirmation." \
        --column "Function" --column "Status" \
        --height=360 --width=380 \
        "${options[@]}"
}

handle_menu() {
    local choice="$1"
    case "$choice" in
        "Conservation Mode")
            local submenu
            submenu="$(show_submenu_on_off "Conservation Mode" "$(get_conservation_mode_status)")"
            case "$submenu" in
                "$SUBMENU_ON")
                    confirm_action "$APP_TITLE" "Enable Conservation Mode (limits charge to prolong battery)?" && apply_sysfs_value "$VPC_PATH/conservation_mode" "1"
                    ;;
                "$SUBMENU_OFF")
                    confirm_action "$APP_TITLE" "Disable Conservation Mode and allow full charge?" && apply_sysfs_value "$VPC_PATH/conservation_mode" "0"
                    ;;
            esac
            ;;
        "Always-On USB")
            local submenu
            submenu="$(show_submenu_on_off "Always-On USB" "$(get_usb_charging_status)")"
            case "$submenu" in
                "$SUBMENU_ON")
                    confirm_action "$APP_TITLE" "Keep USB ports powered while asleep?" && apply_sysfs_value "$VPC_PATH/usb_charging" "1"
                    ;;
                "$SUBMENU_OFF")
                    confirm_action "$APP_TITLE" "Turn off Always-On USB to save battery?" && apply_sysfs_value "$VPC_PATH/usb_charging" "0"
                    ;;
            esac
            ;;
        "Fan Mode")
            local submenu
            submenu="$(show_submenu "Fan Mode" "$(get_fan_mode_status)" \
                "Super Silent" "Standard" "Dust Cleaning" "Efficient Thermal Dissipation")"
            case "$submenu" in
                "Super Silent") confirm_action "$APP_TITLE" "Set fan profile to Super Silent?" && apply_sysfs_value "$VPC_PATH/fan_mode" "0" ;;
                "Standard") confirm_action "$APP_TITLE" "Set fan profile to Standard?" && apply_sysfs_value "$VPC_PATH/fan_mode" "1" ;;
                "Dust Cleaning") confirm_action "$APP_TITLE" "Run Dust Cleaning cycle?" && apply_sysfs_value "$VPC_PATH/fan_mode" "2" ;;
                "Efficient Thermal Dissipation") confirm_action "$APP_TITLE" "Set fan profile to Efficient Thermal Dissipation?" && apply_sysfs_value "$VPC_PATH/fan_mode" "4" ;;
            esac
            ;;
        "FN Lock")
            local submenu
            submenu="$(show_submenu_on_off "FN Lock" "$(get_fn_lock_status)")"
            case "$submenu" in
                "$SUBMENU_ON") confirm_action "$APP_TITLE" "Enable FN Lock (invert F-keys)?" && apply_sysfs_value "$VPC_PATH/fn_lock" "0" ;;
                "$SUBMENU_OFF") confirm_action "$APP_TITLE" "Disable FN Lock?" && apply_sysfs_value "$VPC_PATH/fn_lock" "1" ;;
            esac
            ;;
        "Camera")
            local submenu
            submenu="$(show_submenu_on_off "Camera" "$(get_camera_status)")"
            case "$submenu" in
                "$SUBMENU_ON") confirm_action "$APP_TITLE" "Enable camera module?" && pkexec modprobe uvcvideo ;;
                "$SUBMENU_OFF") confirm_action "$APP_TITLE" "Disable camera module (unload driver)?" && pkexec modprobe -r uvcvideo ;;
            esac
            ;;
        "Microphone")
            local submenu
            submenu="$(show_submenu "Microphone" "$(get_microphone_status)" "Mute" "Unmute")"
            case "$submenu" in
                "Mute") pactl set-source-mute @DEFAULT_SOURCE@ 1 ;;
                "Unmute") pactl set-source-mute @DEFAULT_SOURCE@ 0 ;;
            esac
            ;;
        "Touchpad")
            if [ "$FEATURE_TOUCHPAD" != true ]; then
                warn "This feature requires X11 and is not supported on Wayland."
                return 0
            fi
            local submenu
            submenu="$(show_submenu_on_off "Touchpad" "$(get_touchpad_status "$TOUCHPAD_ID")")"
            case "$submenu" in
                "$SUBMENU_ON") xinput enable "$TOUCHPAD_ID" ;;
                "$SUBMENU_OFF") xinput disable "$TOUCHPAD_ID" ;;
            esac
            ;;
        "WiFi")
            local submenu
            submenu="$(show_submenu_on_off "WiFi" "$(get_wifi_status)")"
            case "$submenu" in
                "$SUBMENU_ON") nmcli radio wifi on ;;
                "$SUBMENU_OFF") nmcli radio wifi off ;;
            esac
            ;;
    esac
}

preflight() {
    detect_session
    require_command zenity
    require_command pkexec
    require_command lsmod
    require_command modprobe
    require_command nmcli
    require_command pactl
    require_environment

    if [ "$FEATURE_XINPUT" = true ]; then
        require_command xinput
    fi

    VPC_PATH="$(resolve_vpc_path)"
    if [ -z "$VPC_PATH" ]; then
        error "VPC2004 platform device not found. This hardware interface is required."
        exit 1
    fi

    TOUCHPAD_ID="$(get_touchpad_id)"
    if [ "$FEATURE_TOUCHPAD" = true ] && [ -z "$TOUCHPAD_ID" ]; then
        warn "Touchpad not detected via xinput; touchpad toggles will be hidden."
    fi
}

main() {
    preflight

    if [ "$SESSION_TYPE" = "wayland" ]; then
        info "Wayland session detected.\n\nSome features (touchpad, xinput-based controls) are disabled.\n\nThis is a Wayland limitation, not an error." &
    fi

    while true; do
        selection="$(main_menu)"
        [ -z "$selection" ] && exit 0
        handle_menu "$selection"
    done
}

main "$@"

