#!/bin/bash
set -euo pipefail

# ===============================================
# K9s Catppuccin Theme Configuration
# ===============================================
# Configures k9s with the Catppuccin Mocha theme.
# Called automatically during post-install or can be run standalone.
#
# Author: Alexis
# Version: 1.0
# Last Updated: 2026-02-09

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Source logging utilities
if [ -f "$SCRIPT_DIR/logs.sh" ]; then
    source "$SCRIPT_DIR/logs.sh"
else
    log() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_success() { echo "[SUCCESS] $1"; }
    log_progress() { echo "[PROGRESS] $1"; }
fi

# ===============================================
# K9s Theme Configuration
# ===============================================

# Check if k9s is installed
if ! command -v k9s &> /dev/null; then
    log_error "k9s is not installed. Install it first with: mise install"
    exit 1
fi

log_progress "Configuring K9s Catppuccin theme..."

# Fetch and set the Catppuccin theme for k9s
THEME_URL="https://github.com/catppuccin/k9s/raw/main/dist/catppuccin-mocha-transparent.yaml"
THEME_DIR="$HOME/.config/k9s/skins"
THEME_FILE="$THEME_DIR/catppuccin-mocha-transparent.yaml"

log_progress "Creating k9s skins directory"
mkdir -p "$THEME_DIR"

log_progress "Downloading Catppuccin theme from GitHub"
if curl -fsSL "$THEME_URL" -o "$THEME_FILE"; then
    log_success "Downloaded theme to $THEME_FILE"
else
    log_error "Failed to download Catppuccin theme"
    exit 1
fi

# Configure k9s to use the theme
CONFIG_FILE="$HOME/.config/k9s/config.yaml"
log_progress "Configuring k9s to use the Catppuccin theme"

mkdir -p "$(dirname "$CONFIG_FILE")"

# Create or update config file
if [ -f "$CONFIG_FILE" ]; then
    # Check if skin is already configured
    if grep -q "skin:" "$CONFIG_FILE"; then
        log_progress "Theme already configured in config.yaml"
    elif grep -q "ui:" "$CONFIG_FILE"; then
        # Add skin under existing ui section
        sed -i.bak '/ui:/a\    skin: catppuccin-mocha-transparent' "$CONFIG_FILE"
        rm -f "${CONFIG_FILE}.bak"
        log_success "Added theme to existing ui section"
    else
        # Add new ui section with skin
        cat >> "$CONFIG_FILE" << EOF

k9s:
  ui:
    skin: catppuccin-mocha-transparent
EOF
        log_success "Created new ui section with theme"
    fi
else
    # Create new config file
    cat > "$CONFIG_FILE" << EOF
k9s:
  ui:
    skin: catppuccin-mocha-transparent
EOF
    log_success "Created new config.yaml with theme"
fi

log_success "K9s Catppuccin theme configured successfully!"
echo
echo "The theme will be applied next time you run k9s."
