#!/bin/bash
set -euo pipefail

# ===============================================
# Helm Plugins Configuration
# ===============================================
# Installs useful Helm plugins for enhanced functionality.
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
    log_warning() { echo "[WARNING] $1"; }
fi

# ===============================================
# Helm Plugin Installation
# ===============================================

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed. Install it first with: mise install"
    exit 1
fi

log_progress "Installing Helm plugins..."

# Install helm-diff plugin
install_helm_diff() {
    if helm plugin list | grep -q "^diff"; then
        log_progress "helm-diff plugin already installed"
        return 0
    fi
    
    log_progress "Installing helm-diff plugin"
    # Try with specific version first, fallback to latest
    if helm plugin install https://github.com/databus23/helm-diff --version v3.9.11 2>/dev/null; then
        log_success "helm-diff v3.9.11 installed"
    else
        log_warning "Failed to install specific version, trying latest"
        if helm plugin install https://github.com/databus23/helm-diff 2>/dev/null; then
            log_success "helm-diff (latest) installed"
        else
            log_error "Failed to install helm-diff plugin"
            return 1
        fi
    fi
}

# Install helm-secrets plugin
install_helm_secrets() {
    if helm plugin list | grep -q "^secrets"; then
        log_progress "helm-secrets plugin already installed"
        return 0
    fi
    
    log_progress "Installing helm-secrets plugin"
    if helm plugin install https://github.com/jkroepke/helm-secrets 2>/dev/null; then
        log_success "helm-secrets installed"
    else
        log_error "Failed to install helm-secrets plugin"
        return 1
    fi
}

# Install plugins with error handling
FAILED_PLUGINS=()

if ! install_helm_diff; then
    FAILED_PLUGINS+=("helm-diff")
fi

if ! install_helm_secrets; then
    FAILED_PLUGINS+=("helm-secrets")
fi

# Summary
echo
if [ ${#FAILED_PLUGINS[@]} -eq 0 ]; then
    log_success "All Helm plugins installed successfully!"
    echo
    echo "Installed plugins:"
    helm plugin list
else
    log_warning "Some Helm plugins failed to install: ${FAILED_PLUGINS[*]}"
    echo
    echo "Successfully installed plugins:"
    helm plugin list
    exit 1
fi
