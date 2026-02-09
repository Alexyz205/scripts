#!/bin/bash
set -euo pipefail

# ===============================================
# Development Tools Package Installer (Mise-based)
# ===============================================
# Installs mise and uses it to manage all development tools.
# All tool versions are managed via config/mise/config.toml
#
# Author: Alexis
# Version: 4.0
# Last Updated: 2026-02-09

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Initialize error handling
if [ -f "$SCRIPT_DIR/error_handling.sh" ]; then
  source "$SCRIPT_DIR/error_handling.sh"
  init_error_handling "install-packages"
else
  set -euo pipefail
fi

source "$SCRIPT_DIR/logs.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/checker.sh"

# Parse command line arguments
FORCE_INSTALL=false

for arg in "$@"; do
  case $arg in
  --force)
    FORCE_INSTALL=true
    shift
    ;;
  --help)
    section_header "Package Installation Help"
    echo "Usage: install_packages [--help] [--force]"
    echo "This script installs mise and uses it to manage all development tools."
    echo
    echo "Options:"
    echo "  --help    Show this help message and exit"
    echo "  --force   Force reinstallation of all packages"
    echo
    echo "All tools are defined in config/mise/config.toml"
    echo "To see available tools: mise list"
    echo "To add tools: Edit config/mise/config.toml and run 'mise install'"
    echo "To update tools: mise upgrade"
    exit 0
    ;;
  *)
    if [[ "$arg" != "" ]]; then
      log_error "Unknown option: $arg"
      echo "Use --help for usage information."
      exit 1
    fi
    ;;
  esac
done

section_header "Development Tools Installation (Mise)"

if [ "$FORCE_INSTALL" = true ]; then
  log_warning "Force mode enabled - all packages will be reinstalled"
fi

# ===============================================
# System Validation
# ===============================================

log_progress "Validating system prerequisites"
if ! validate_dependencies "curl" "tar" "git"; then
  error_exit "Missing critical dependencies for package installation"
fi

check_architecture
log_success "System validation completed successfully"

# ===============================================
# Mise Installation
# ===============================================

if ! command -v mise &>/dev/null; then
  log_progress "Installing mise..."
  curl -fsSL https://mise.run | sh

  # Add mise to PATH for this session
  export PATH="$HOME/.local/bin:$PATH"

  if command -v mise &>/dev/null; then
    log_success "mise installed successfully"
  else
    error_exit "Failed to install mise"
  fi
else
  log_success "mise is already installed"
  mise --version
fi

# ===============================================
# Tool Installation via Mise
# ===============================================

log_progress "Installing all tools from config/mise/config.toml..."

if [ "$FORCE_INSTALL" = true ]; then
  mise install --force
else
  mise install
fi

log_success "All mise tools installed successfully"

# ===============================================
# Post-Install Configuration
# ===============================================

section_header "Post-Install Configuration"

# Configure K9s theme
if command -v k9s &>/dev/null; then
  log_progress "Configuring k9s Catppuccin theme..."
  if bash "$SCRIPT_DIR/configure_k9s.sh" 2>/dev/null; then
    log_success "k9s theme configured"
  else
    log_warning "k9s theme configuration failed (non-critical)"
  fi
fi

# Configure Helm plugins
if command -v helm &>/dev/null; then
  log_progress "Installing Helm plugins..."
  if bash "$SCRIPT_DIR/configure_helm.sh" 2>/dev/null; then
    log_success "Helm plugins installed"
  else
    log_warning "Helm plugins installation failed (non-critical)"
  fi
fi

# ===============================================
# Verification
# ===============================================

section_header "Installation Verification"
log_progress "Verifying tool installations..."

mise doctor

section_header "Installation Summary"
log_complete "All tools have been successfully installed via mise!"
echo
echo "Installed tools:"
mise list
echo
echo "Next steps:"
echo "  1. Restart your shell or run: exec zsh"
echo "  2. Verify tools work: starship --version, fzf --version, etc."
echo
echo "Useful commands:"
echo "  mise list     - Show all installed tools"
echo "  mise upgrade  - Update all tools to latest versions"
echo "  mise doctor   - Check for issues"
