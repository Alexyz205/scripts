#!/bin/bash
set -euo pipefail

# ===============================================
# Error Handling and Recovery Framework
# ===============================================
# This script provides robust error handling, logging, and recovery mechanisms
# for all scripts in the dotfiles repository.
#
# Author: Alexis
# Version: 2.0
# Last Updated: 2026-01-14

# Global error handling state
# Check if we're running in bash with associative array support
if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
    declare -A SCRIPT_STATE
    declare -A CLEANUP_FUNCTIONS
    declare -A ROLLBACK_STACK
else
    # Fallback for shells without associative array support
    # Use simple variables with prefixes
    SCRIPT_STATE_started=""
    SCRIPT_STATE_status=""
    SCRIPT_STATE_errors=""
fi

ERROR_LOG_FILE=""
SCRIPT_NAME=""
RECOVERY_MODE=false
MAX_RETRIES=3

# Helper functions for cross-shell compatibility
set_script_state() {
    local key="$1"
    local value="$2"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        SCRIPT_STATE["$key"]="$value"
    else
        eval "SCRIPT_STATE_${key}='$value'"
    fi
}

get_script_state() {
    local key="$1"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        echo "${SCRIPT_STATE[$key]:-}"
    else
        eval "echo \"\${SCRIPT_STATE_${key}:-}\""
    fi
}

set_cleanup_function() {
    local key="$1"
    local value="$2"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        CLEANUP_FUNCTIONS["$key"]="$value"
    else
        eval "CLEANUP_${key}='$value'"
    fi
}

get_cleanup_function() {
    local key="$1"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        echo "${CLEANUP_FUNCTIONS[$key]:-}"
    else
        eval "echo \"\${CLEANUP_${key}:-}\""
    fi
}

set_rollback_operation() {
    local key="$1"
    local value="$2"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        ROLLBACK_STACK["$key"]="$value"
    else
        eval "ROLLBACK_${key}='$value'"
    fi
}

get_rollback_operation() {
    local key="$1"
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        echo "${ROLLBACK_STACK[$key]:-}"
    else
        eval "echo \"\${ROLLBACK_${key}:-}\""
    fi
}

# Initialize error handling for a script
init_error_handling() {
    local script_name="$1"
    SCRIPT_NAME="$script_name"
    
    # Set strict mode
    set -euo pipefail
    
    # Set up error log
    ERROR_LOG_FILE="/tmp/dotfiles_error_${script_name}_$(date +%F-%H%M%S).log"
    
    # Initialize script state
    set_script_state "started" "$(date +%s)"
    set_script_state "status" "running"
    set_script_state "errors" "0"
    
    # Set up trap handlers
    trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
    trap 'exit_handler $?' EXIT
    trap 'interrupt_handler' INT TERM
    
    # Log script start
    log_debug "Error handling initialized for script: $script_name"
}

# Main error handler
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_line_no=$3
    local last_command="$4"
    local func_stack="$5"
    
    set_script_state "status" "error"
    local current_errors=$(get_script_state "errors")
    set_script_state "errors" "$((current_errors + 1))"
    
    # Log error details
    {
        echo "================================"
        echo "ERROR OCCURRED IN SCRIPT: $SCRIPT_NAME"
        echo "Timestamp: $(date)"
        echo "Exit code: $exit_code"
        echo "Line number: $line_no"
        echo "Bash line number: $bash_line_no"
        echo "Failed command: $last_command"
        echo "Function stack: $func_stack"
        echo "================================"
        echo "Environment:"
        echo "PWD: $PWD"
        echo "USER: $USER"
        echo "Shell: $SHELL"
        echo "PATH: $PATH"
        echo "================================"
    } >> "$ERROR_LOG_FILE"
    
    # Attempt recovery if enabled
    if [ "$RECOVERY_MODE" = true ]; then
        log_warning "Attempting error recovery..."
        if attempt_recovery "$exit_code" "$last_command"; then
            log_info "Recovery successful, continuing execution"
            return 0
        else
            log_error "Recovery failed, executing cleanup"
        fi
    fi
    
    # Execute rollback operations
    execute_rollback
    
    # Don't exit immediately, let the exit handler manage cleanup
    return $exit_code
}

# Exit handler
exit_handler() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        set_script_state "status" "failed"
        log_error "Script $SCRIPT_NAME failed with exit code $exit_code"
        
        # Copy error log to user's home directory
        if [ -f "$ERROR_LOG_FILE" ]; then
            local user_error_log="$HOME/dotfiles_error_${SCRIPT_NAME}_$(date +%F-%H%M%S).log"
            cp "$ERROR_LOG_FILE" "$user_error_log"
            echo "Error log saved to: $user_error_log" >&2
        fi
    else
        set_script_state "status" "completed"
        log_debug "Script $SCRIPT_NAME completed successfully"
    fi
    
    # Execute cleanup functions
    execute_cleanup_functions
    
    # Clean up temporary error log if script succeeded
    if [ $exit_code -eq 0 ] && [ -f "$ERROR_LOG_FILE" ]; then
        rm -f "$ERROR_LOG_FILE"
    fi
    
    exit $exit_code
}

# Interrupt handler
interrupt_handler() {
    set_script_state "status" "interrupted"
    log_warning "Script $SCRIPT_NAME interrupted by user"
    
    echo "Interrupt received, cleaning up..." >&2
    execute_rollback
    execute_cleanup_functions
    
    exit 130
}

# Register a cleanup function
register_cleanup() {
    local cleanup_function="$1"
    local cleanup_id="${2:-$(date +%s%N)}"
    
    set_cleanup_function "$cleanup_id" "$cleanup_function"
    log_debug "Registered cleanup function: $cleanup_function"
}

# Register a rollback operation
register_rollback() {
    local rollback_operation="$1"
    local operation_id="${2:-$(date +%s%N)}"
    
    set_rollback_operation "$operation_id" "$rollback_operation"
    log_debug "Registered rollback operation: $rollback_operation"
}

# Execute all cleanup functions
execute_cleanup_functions() {
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        for cleanup_id in "${!CLEANUP_FUNCTIONS[@]}"; do
            local cleanup_function="${CLEANUP_FUNCTIONS[$cleanup_id]}"
            log_debug "Executing cleanup: $cleanup_function"
            
            if ! eval "$cleanup_function" 2>>/dev/null; then
                log_warning "Cleanup function failed: $cleanup_function"
            fi
        done
        
        # Clear cleanup functions
        CLEANUP_FUNCTIONS=()
    else
        # Fallback for shells without associative arrays
        # Execute all CLEANUP_* variables
        for var in $(env | grep '^CLEANUP_' | cut -d= -f1); do
            local cleanup_function
            eval "cleanup_function=\$$var"
            log_debug "Executing cleanup: $cleanup_function"
            
            if ! eval "$cleanup_function" 2>>/dev/null; then
                log_warning "Cleanup function failed: $cleanup_function"
            fi
            
            # Clear the variable
            unset "$var"
        done
    fi
}

# Execute rollback operations in reverse order
execute_rollback() {
    if [ "${BASH_VERSION:-}" ] && [[ "${BASH_VERSION}" =~ ^[4-9] ]]; then
        if [ ${#ROLLBACK_STACK[@]} -eq 0 ]; then
            return 0
        fi
        
        log_info "Executing rollback operations..."
        
        # Get keys in reverse order
        local keys=($(printf '%s\n' "${!ROLLBACK_STACK[@]}" | sort -nr))
        
        for key in "${keys[@]}"; do
            local rollback_op="${ROLLBACK_STACK[$key]}"
            log_debug "Rolling back: $rollback_op"
            
            if ! eval "$rollback_op" 2>/dev/null; then
                log_warning "Rollback operation failed: $rollback_op"
            fi
        done
        
        # Clear rollback stack
        ROLLBACK_STACK=()
    else
        # Fallback for shells without associative arrays
        local rollback_vars=($(env | grep '^ROLLBACK_' | cut -d= -f1 | sort -r 2>/dev/null || true))
        
        if [ ${#rollback_vars[@]} -eq 0 ]; then
            return 0
        fi
        
        log_info "Executing rollback operations..."
        
        for var in "${rollback_vars[@]}"; do
            local rollback_op
            eval "rollback_op=\$$var" 2>/dev/null || continue
            log_debug "Rolling back: $rollback_op"
            
            if ! eval "$rollback_op" 2>/dev/null; then
                log_warning "Rollback operation failed: $rollback_op"
            fi
            
            # Clear the variable
            unset "$var" 2>/dev/null || true
        done
    fi
}

# Attempt error recovery
attempt_recovery() {
    local exit_code=$1
    local failed_command="$2"
    
    # Simple recovery strategies
    case $exit_code in
        1) # General error
            log_info "Attempting general error recovery"
            return 1 # No specific recovery for general errors
            ;;
        2) # Command not found
            log_info "Command not found error detected"
            return 1 # Cannot recover from missing commands
            ;;
        126) # Command not executable
            log_info "Command not executable, attempting to fix permissions"
            if [[ "$failed_command" =~ ^[^[:space:]]+[[:space:]] ]]; then
                local cmd=${failed_command%% *}
                if [ -f "$cmd" ]; then
                    chmod +x "$cmd" 2>/dev/null && return 0
                fi
            fi
            return 1
            ;;
        127) # Command not found
            log_info "Command not found error"
            return 1
            ;;
        *) # Other errors
            return 1
            ;;
    esac
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts="$1"
    local delay="$2"
    local command="$3"
    
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_debug "Attempt $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2)) # Exponential backoff
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "All $max_attempts attempts failed for command: $command"
    return 1
}

# Network operation with retry
network_retry() {
    local url="$1"
    local output_file="$2"
    local max_attempts="${3:-3}"
    
    local command="curl -fsSL --connect-timeout 10 --max-time 300 '$url' -o '$output_file'"
    
    if ! retry_with_backoff "$max_attempts" 2 "$command"; then
        log_error "Failed to download from $url after $max_attempts attempts"
        return 1
    fi
    
    return 0
}

# Safe file operation with backup
safe_file_operation() {
    local operation="$1"
    local target_file="$2"
    local backup_suffix="${3:-.backup}"
    
    # Create backup if file exists
    if [ -f "$target_file" ]; then
        local backup_file="${target_file}${backup_suffix}.$(date +%s)"
        cp "$target_file" "$backup_file"
        register_rollback "mv '$backup_file' '$target_file'"
        register_cleanup "rm -f '$backup_file'"
    fi
    
    # Execute the operation
    eval "$operation"
}

# Validate critical dependencies
validate_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing critical dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again"
        return 1
    fi
    
    return 0
}

# Check if script is running as expected user
validate_user() {
    local expected_user="$1"
    
    if [ "$USER" != "$expected_user" ]; then
        log_error "Script must be run as user: $expected_user (current: $USER)"
        return 1
    fi
    
    return 0
}

# Check available disk space
check_disk_space() {
    local required_space_mb="$1"
    local target_dir="${2:-/tmp}"
    
    local available_space_kb=$(df "$target_dir" | tail -1 | awk '{print $4}')
    local available_space_mb=$((available_space_kb / 1024))
    
    if [ $available_space_mb -lt $required_space_mb ]; then
        log_error "Insufficient disk space. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB"
        return 1
    fi
    
    return 0
}

# Enable recovery mode
enable_recovery() {
    RECOVERY_MODE=true
    log_info "Recovery mode enabled"
}

# Disable recovery mode
disable_recovery() {
    RECOVERY_MODE=false
    log_info "Recovery mode disabled"
}

# Get script status
get_script_status() {
    get_script_state "status"
}

# Get error count
get_error_count() {
    get_script_state "errors"
}

# Simple logging functions (if not already available)
if ! declare -f log_debug >/dev/null; then
    log_debug() { echo "[DEBUG] $*" >&2; }
fi

if ! declare -f log_info >/dev/null; then
    log_info() { echo "[INFO] $*" >&2; }
fi

if ! declare -f log_warning >/dev/null; then
    log_warning() { echo "[WARNING] $*" >&2; }
fi

if ! declare -f log_error >/dev/null; then
    log_error() { echo "[ERROR] $*" >&2; }
fi