#!/bin/bash

set -e

SERVICE_NAME="hdmi-keepalive.service"
SERVICE_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_dependencies() {
    if ! command -v pacat &> /dev/null; then
        error "pacat not found. Please install pulseaudio-utils:
    Fedora:       sudo dnf install pulseaudio-utils
    Ubuntu/Debian: sudo apt install pulseaudio-utils
    Arch:         sudo pacman -S libpulse"
    fi

    if ! command -v systemctl &> /dev/null; then
        error "systemctl not found. This script requires systemd."
    fi
}

install() {
    info "Installing $SERVICE_NAME..."

    check_dependencies

    # Create user systemd directory if it doesn't exist
    mkdir -p "$SERVICE_DIR"

    # Copy service file
    if [[ ! -f "$SCRIPT_DIR/$SERVICE_NAME" ]]; then
        error "Service file not found: $SCRIPT_DIR/$SERVICE_NAME"
    fi

    cp "$SCRIPT_DIR/$SERVICE_NAME" "$SERVICE_DIR/"
    info "Copied service file to $SERVICE_DIR/"

    # Reload systemd
    systemctl --user daemon-reload
    info "Reloaded systemd user daemon"

    # Enable and start service
    systemctl --user enable --now "$SERVICE_NAME"
    info "Enabled and started $SERVICE_NAME"

    echo ""
    info "Installation complete!"
    echo ""
    echo "Check status with:"
    echo "  systemctl --user status $SERVICE_NAME"
    echo ""
    echo "View logs with:"
    echo "  journalctl --user -u $SERVICE_NAME -f"
}

uninstall() {
    info "Uninstalling $SERVICE_NAME..."

    # Stop and disable service (ignore errors if not running)
    systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null || true
    info "Stopped and disabled service"

    # Remove service file
    if [[ -f "$SERVICE_DIR/$SERVICE_NAME" ]]; then
        rm "$SERVICE_DIR/$SERVICE_NAME"
        info "Removed service file"
    fi

    # Reload systemd
    systemctl --user daemon-reload
    info "Reloaded systemd user daemon"

    echo ""
    info "Uninstallation complete!"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install or uninstall the HDMI audio keepalive service."
    echo ""
    echo "Options:"
    echo "  --install     Install the service (default)"
    echo "  --uninstall   Remove the service"
    echo "  --status      Show service status"
    echo "  --help        Show this help message"
}

status() {
    systemctl --user status "$SERVICE_NAME"
}

# Parse arguments
case "${1:-}" in
    --uninstall|-u)
        uninstall
        ;;
    --status|-s)
        status
        ;;
    --help|-h)
        usage
        ;;
    --install|-i|"")
        install
        ;;
    *)
        error "Unknown option: $1"
        ;;
esac
