#!/bin/bash
set -euo pipefail

# ===============================================
# System Validation and Checker Utilities
# ===============================================
# Provides functions for checking architecture, sudo access, and other system requirements.
# Ensures system compatibility before running installation or configuration scripts.
#
# Author: Alexis
# Version: 2.0
# Last Updated: 2026-01-14

# Check for supported system architecture
check_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        log_error "Unsupported architecture: $ARCH"
        log "This script only supports x86_64 and aarch64 architectures."
        exit 1
    fi

    # Set the architecture variable for other scripts to use
    export ARCH

    # Architecture-specific message
    log "Detected architecture: $ARCH"
}

# Check if sudo is available and set SUDO variable accordingly
check_sudo() {
    if command -v sudo &> /dev/null; then
        log_progress "Sudo is available and will be used for privileged operations"
        SUDO="sudo"
    else
        log_warning "Sudo is not available. Running with current user privileges."
        log_warning "Some operations may fail if they require elevated permissions."
        SUDO=""
    fi

    # Export the SUDO variable
    export SUDO
}

# Function to create a sudo wrapper that works correctly
setup_sudo_wrapper() {
    # Create a global sudo wrapper function
    # When sudo is available, this calls the real sudo
    # When sudo is not available, it just runs the command directly
    if [ -n "$SUDO" ]; then
        sudo() {
            command sudo "$@"
        }
    else
        sudo() {
            "$@"
        }
    fi

    # Export the sudo function for subshells
    export -f sudo
}

# Check for minimum system requirements
# Note: This function assumes Linux-style /proc/meminfo for memory checking
# On macOS or other systems, memory checks may not work correctly
check_system_requirements() {
    # Check total memory (in MB) - Linux only
    if [ -f /proc/meminfo ]; then
        local mem_total
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024}' | cut -d. -f1)
        local min_memory=1024 # 1GB minimum

        if [ "$mem_total" -lt "$min_memory" ]; then
            log_warning "System has only ${mem_total}MB of RAM. Minimum recommended is ${min_memory}MB."
            log_warning "Installation may be slow or fail due to insufficient memory."
        else
            log "System memory check passed: ${mem_total}MB available"
        fi
    else
        log_warning "Cannot check system memory (not a Linux system)"
    fi

    # Check disk space in GB (available in current directory)
    local disk_space
    if command -v df >/dev/null; then
        disk_space=$(df -BG . 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//') || {
            log_warning "Could not determine disk space availability"
            return 0
        }
        local min_disk=5 # 5GB minimum

        if [ -n "$disk_space" ] && [ "$disk_space" -lt "$min_disk" ]; then
            log_warning "Only ${disk_space}GB of disk space available. Minimum recommended is ${min_disk}GB."
            log_warning "Installation may fail due to insufficient disk space."
        elif [ -n "$disk_space" ]; then
            log "Disk space check passed: ${disk_space}GB available"
        fi
    else
        log_warning "Cannot check disk space (df command not available)"
    fi
}
