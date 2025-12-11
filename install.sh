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

detect_audio_tool() {
    # Prefer pacat - it works with both PulseAudio and PipeWire (via pipewire-pulse)
    # and handles continuous streaming from /dev/zero more reliably
    if command -v pacat &> /dev/null; then
        AUDIO_TOOL="pacat"
        AUDIO_CMD="/usr/bin/pacat -p --rate=48000 --channels=2 --format=s16le /dev/zero"
        # Check if running under PipeWire
        if pactl info 2>/dev/null | grep -q "PipeWire"; then
            info "Detected PipeWire with PulseAudio compatibility (pacat)"
        else
            info "Detected PulseAudio (pacat)"
        fi
    elif command -v pw-cat &> /dev/null; then
        AUDIO_TOOL="pw-cat"
        AUDIO_CMD="/usr/bin/pw-cat -p --raw --rate=48000 --channels=2 --format=s16 /dev/zero"
        info "Detected PipeWire native (pw-cat)"
        warn "Note: pw-cat may require periodic restarts; consider installing pulseaudio-utils for better reliability"
    else
        error "No audio tool found. Please install one of:
    Recommended (works with both PulseAudio and PipeWire):
        Fedora:        sudo dnf install pulseaudio-utils
        Ubuntu/Debian: sudo apt install pulseaudio-utils
        Arch:          sudo pacman -S libpulse

    PipeWire native (alternative):
        Fedora:        sudo dnf install pipewire-utils
        Ubuntu/Debian: sudo apt install pipewire
        Arch:          sudo pacman -S pipewire"
    fi
}

check_dependencies() {
    detect_audio_tool

    if ! command -v systemctl &> /dev/null; then
        error "systemctl not found. This script requires systemd."
    fi
}

generate_service_file() {
    cat > "$SERVICE_DIR/$SERVICE_NAME" << EOF
[Unit]
Description=HDMI Audio Keep-Alive Silent Stream
After=pipewire.service pulseaudio.service

[Service]
Type=simple
ExecStart=$AUDIO_CMD
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
}

install() {
    info "Installing $SERVICE_NAME..."

    check_dependencies

    # Create user systemd directory if it doesn't exist
    mkdir -p "$SERVICE_DIR"

    # Generate service file with detected audio tool
    generate_service_file
    info "Generated service file using $AUDIO_TOOL"

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
