# Scripts Directory

This directory contains the core automation scripts for the dotfiles repository, following **Clean Architecture** principles for maintainability and testability.

## 📋 Script Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| **logs.sh** | Logging system with structured output | Sourced by all scripts |
| **error_handling.sh** | Comprehensive error handling & recovery | Sourced for critical operations |
| **checker.sh** | System validation (architecture, sudo, requirements) | Sourced for system checks |
| **utils.sh** | Common utilities (temp dirs, dependencies, installs) | Sourced for shared functions |
| **setup.sh** | Creates symlinks and configuration directories | Run directly or via setup_dotfiles |
| **install_packages.sh** | Installs development tools using mise | Run directly with optional --force |
| **configure_helm.sh** | Configures Helm plugins (diff, secrets) | Called by install_packages or run standalone |
| **configure_k9s.sh** | Sets up Catppuccin theme for k9s | Called by install_packages or run standalone |

## 🏗️ Architecture

### Layered Design

```
┌─────────────────────────────────────────┐
│   Entry Points (install, setup_dotfiles)│
├─────────────────────────────────────────┤
│   Installation Scripts                  │
│   • install_packages.sh                 │
│   • configure_helm.sh                   │
│   • configure_k9s.sh                    │
│   • setup.sh                            │
├─────────────────────────────────────────┤
│   Core Utilities Layer                  │
│   • utils.sh (shared functions)         │
│   • checker.sh (validation)             │
├─────────────────────────────────────────┤
│   Infrastructure Layer                  │
│   • logs.sh (logging)                   │
│   • error_handling.sh (error mgmt)      │
└─────────────────────────────────────────┘
```

### Design Principles

1. **Separation of Concerns**: Each script has a single, well-defined responsibility
2. **Dependency Injection**: Scripts source required dependencies explicitly
3. **Error Handling**: Comprehensive error handling with cleanup and rollback
4. **Idempotency**: Scripts can be run multiple times safely
5. **Cross-Platform**: Support for Linux (x86_64/aarch64) and macOS

## 🔧 Core Components

### Logging System (logs.sh)

Provides standardized logging with timestamps:

```bash
source "$SCRIPT_DIR/logs.sh"
log "Information message"
log_error "Error message"
log_warning "Warning message"
log_success "Success message"
log_progress "Progress update"
log_complete "Completion message"
```

### Error Handling (error_handling.sh)

Robust error handling with automatic cleanup:

```bash
source "$SCRIPT_DIR/error_handling.sh"
init_error_handling "script-name"

# Register cleanup operations
register_cleanup "rm -f /tmp/tempfile"

# Register rollback operations
register_rollback "mv backup original"

# Retry operations with exponential backoff
retry_with_backoff 3 2 "curl -fsSL https://example.com"
```

### System Validation (checker.sh)

Platform and system requirement checks:

```bash
source "$SCRIPT_DIR/checker.sh"
check_architecture          # Validates x86_64 or aarch64
check_sudo                  # Checks sudo availability
check_system_requirements   # Validates RAM and disk space
```

### Common Utilities (utils.sh)

Shared functions for all scripts:

```bash
source "$SCRIPT_DIR/utils.sh"

# Temporary directory management
TEMP_DIR=$(create_temp_dir "prefix")
cleanup_temp_dir "$TEMP_DIR"

# Run commands in temp directories
run_in_temp_dir "package" "curl -LO url && tar -xzf file"

# Dependency validation
validate_dependencies "curl" "git" "tar"

# Installation management
install_command "tool" "install_cmd" "check_cmd" "" false
```

## 📦 Installation Scripts

### install_packages.sh

Installs all development tools using **mise** as the package manager. Tool versions are managed in `../config/mise/config.toml`:

```bash
# Install all packages
./scripts/install_packages.sh

# Force reinstall
./scripts/install_packages.sh --force

# Show help
./scripts/install_packages.sh --help
```

**What it does**:

1. Installs mise (if not already present)
2. Installs all tools defined in `config/mise/config.toml`
3. Configures k9s with Catppuccin theme
4. Installs Helm plugins (diff, secrets)

**Installed Tools** (see `config/mise/config.toml` for full list):

- **Shell & Terminal**: starship, zoxide, fzf, tmux
- **File & Text**: ripgrep, fd, bat, eza, yazi
- **Version Control**: lazygit
- **Editors**: nvim, tree-sitter
- **Languages**: node, python
- **Infrastructure**: terraform, ansible
- **Kubernetes**: kubectl, k9s, helm, helmfile
- **AI Assistant**: opencode-ai

### configure_helm.sh

Configures Helm with useful plugins:

```bash
./scripts/configure_helm.sh
```

**Installed Plugins**:

- **helm-diff** (v3.9.11): Show diffs before applying changes
- **helm-secrets**: Manage encrypted secrets in Helm charts

### configure_k9s.sh

Sets up k9s with Catppuccin Mocha theme:

```bash
./scripts/configure_k9s.sh
```

**What it does**:

- Downloads Catppuccin Mocha transparent theme
- Configures k9s to use the theme automatically

### setup.sh

Creates symlinks and configuration directories:

```bash
./scripts/setup.sh
```

Creates XDG Base Directory structure and symlinks for:

- Shell configs (zsh, bash)
- Terminal (ghostty, tmux)
- Editor (nvim)
- Tools (starship, lazygit, opencode)

## 🔒 Security Considerations

1. **Sudo Handling**: Scripts detect sudo availability and fail gracefully
2. **Download Verification**: All downloads log URLs for audit trails
3. **Temporary Files**: Automatic cleanup prevents leftover sensitive data
4. **Error Logs**: Errors logged to home directory for troubleshooting

## 📊 Version Management

Tool versions are managed in `../config/mise/config.toml`:

```toml
[tools]
# Programming Languages
node = "24.11.1"
python = "3.14.3"

# Shell Tools
"ubi:starship/starship" = "1.24.1"
"ubi:ajeetdsouza/zoxide" = "0.9.8"

# Kubernetes Tools
kubectl = "1.34.1"
"ubi:derailed/k9s" = "0.50.12"
helm = "3.19.0"
# ...
```

Update versions in the config file and re-run `mise install` to upgrade tools.

---

**Version**: 2.1  
**Last Updated**: 2026-02-09  
**Maintained by**: Alexis
