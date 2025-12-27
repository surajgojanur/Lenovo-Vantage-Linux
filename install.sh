#!/bin/bash

set -euo pipefail

DRY_RUN=0
SESSION_TYPE="unknown"

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run]

Installs required dependencies for Lenovo Vantage on supported distros.

Options:
  --dry-run   Show what would be done without making changes.
  -h, --help  Show this help.
EOF
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

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log ERROR "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log DRY-RUN "$*"
        return 0
    fi
    "$@"
}

ensure_root() {
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        log ERROR "This installer must be run as root or with sudo."
        exit 1
    fi
}

detect_package_manager() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ -n "${ID_LIKE:-}" ]; then
            echo "$ID_LIKE"
        else
            echo "$ID"
        fi
    else
        echo "unknown"
    fi
}

systemctl_available() {
    command -v systemctl >/dev/null 2>&1
}

packages_for_pm() {
    local pm="$1"
    case "$pm" in
        pacman)
            echo "zenity xorg-xinput networkmanager"
            ;;
        apt)
            echo "zenity xinput network-manager"
            ;;
        dnf)
            echo "zenity xinput NetworkManager pipewire-pulseaudio"
            ;;
        zypper)
            echo "zenity xinput NetworkManager pipewire-pulseaudio"
            ;;
        *)
            echo ""
            ;;
    esac
}

missing_packages() {
    local pm="$1"; shift
    local pkgs=("$@")
    local missing=()

    case "$pm" in
        pacman)
            for pkg in "${pkgs[@]}"; do
                if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
                    missing+=("$pkg")
                fi
            done
            ;;
        apt)
            for pkg in "${pkgs[@]}"; do
                if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                    missing+=("$pkg")
                fi
            done
            ;;
        dnf|zypper)
            for pkg in "${pkgs[@]}"; do
                if ! rpm -q "$pkg" >/dev/null 2>&1; then
                    missing+=("$pkg")
                fi
            done
            ;;
    esac

    printf '%s\n' "${missing[*]}"
}

install_packages() {
    local pm="$1"; shift
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        log INFO "All required packages are already installed."
        return 0
    fi

    case "$pm" in
        pacman)
            run_cmd pacman -S --needed "${pkgs[@]}"
            ;;
        apt)
            run_cmd apt update
            run_cmd apt install -y "${pkgs[@]}"
            ;;
        dnf)
            run_cmd dnf install -y "${pkgs[@]}"
            ;;
        zypper)
            run_cmd zypper install -y "${pkgs[@]}"
            ;;
        *)
            log ERROR "Unsupported package manager: $pm"
            return 1
            ;;
    esac
}

main() {
    parse_args "$@"

    detect_session

    local distro pm pkgs missing
    distro="$(detect_distro)"
    pm="$(detect_package_manager)"

    if [ "$pm" = "unknown" ]; then
        log ERROR "Could not detect a supported package manager. Supported: pacman, apt, dnf, zypper."
        exit 1
    fi

    pkgs="$(packages_for_pm "$pm")"
    if [ -z "$pkgs" ]; then
        log ERROR "No package mapping for detected manager: $pm"
        exit 1
    fi

    read -r -a pkg_array <<< "$pkgs"

    if ! systemctl_available; then
        log WARN "systemctl not available; NetworkManager status cannot be verified."
    fi

    ensure_root

    log INFO "Detected distro hint: $distro"
    log INFO "Using package manager: $pm"

    if [ "$SESSION_TYPE" = "wayland" ]; then
        log INFO "NOTE: You are using Wayland. Some features (touchpad control, xinput-based functions) will be unavailable."
    fi

    missing=$(missing_packages "$pm" "${pkg_array[@]}")
    if [ -z "$missing" ]; then
        log INFO "Dependencies already satisfied: $pkgs"
        exit 0
    fi

    # Rehydrate missing list into an array
    read -r -a missing_array <<< "$missing"
    log INFO "Missing packages: $missing"
    install_packages "$pm" "${missing_array[@]}"

    log INFO "Dependency installation complete."
}

main "$@"
