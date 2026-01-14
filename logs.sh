#!/bin/bash
set -euo pipefail

# ===============================================
# Logging System for Dotfiles Scripts
# ===============================================
# Provides standardized logging functions with timestamp and log type.
# Supports both human-readable and JSON structured logging formats.
#
# Author: Alexis
# Version: 2.1
# Last Updated: 2026-01-14

# Configuration: Set LOG_FORMAT environment variable
# - "text" (default): Human-readable format
# - "json": Structured JSON format for production/automation
LOG_FORMAT="${LOG_FORMAT:-text}"

# Function to get current timestamp in ISO 8601 format
get_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

# Function to get current timestamp in Unix epoch format
get_timestamp_epoch() {
  date +"%s"
}

# Escape JSON strings
json_escape() {
  local string="$1"
  # Escape special characters for JSON
  printf '%s' "$string" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g'
}

# Core JSON logging function
log_json() {
  local level="$1"
  local message="$2"
  local script="${3:-${BASH_SOURCE[2]##*/}}"
  local line="${4:-${BASH_LINENO[1]}}"
  
  # Escape message for JSON
  local escaped_message
  escaped_message=$(json_escape "$message")
  
  # Output structured JSON log
  cat <<EOF
{"timestamp":"$(get_timestamp)","epoch":$(get_timestamp_epoch),"level":"$level","message":"$escaped_message","script":"$script","line":$line,"pid":$$,"user":"$USER"}
EOF
}

# Core logging function - supports both text and JSON formats
_log() {
  local level="$1"
  local message="$2"
  
  if [ "$LOG_FORMAT" = "json" ]; then
    log_json "$level" "$message"
  else
    echo "[$(get_timestamp)][${level}] $message"
  fi
}

# Public logging functions
log() { _log "INFO" "$1"; }
log_error() { _log "ERROR" "$1"; }
log_success() { _log "SUCCESS" "$1"; }
log_warning() { _log "WARNING" "$1"; }
log_debug() { _log "DEBUG" "$1"; }

# Task-specific logging functions
log_install() { _log "INSTALL" "$1"; }
log_setup() { _log "SETUP" "$1"; }
log_progress() { _log "PROGRESS" "$1"; }
log_complete() { _log "COMPLETE" "$1"; }

# Error and exit helper
error_exit() { 
  log_error "$1"
  exit 1
}

# Section header - only in text mode
section_header() {
  local title="$1"
  
  if [ "$LOG_FORMAT" = "json" ]; then
    log_json "SECTION" "$title"
  else
    echo -e "\n===== $title =====\n"
  fi
}

# Log with additional context (only in JSON mode)
log_with_context() {
  local level="$1"
  local message="$2"
  shift 2
  local context="$*"
  
  if [ "$LOG_FORMAT" = "json" ]; then
    local escaped_message escaped_context
    escaped_message=$(json_escape "$message")
    escaped_context=$(json_escape "$context")
    
    cat <<EOF
{"timestamp":"$(get_timestamp)","epoch":$(get_timestamp_epoch),"level":"$level","message":"$escaped_message","context":"$escaped_context","script":"${BASH_SOURCE[1]##*/}","line":${BASH_LINENO[0]},"pid":$$,"user":"$USER"}
EOF
  else
    _log "$level" "$message [$context]"
  fi
}

# Performance logging - log with duration
log_duration() {
  local operation="$1"
  local start_time="$2"
  local end_time
  end_time=$(get_timestamp_epoch)
  local duration=$((end_time - start_time))
  
  if [ "$LOG_FORMAT" = "json" ]; then
    local escaped_operation
    escaped_operation=$(json_escape "$operation")
    
    cat <<EOF
{"timestamp":"$(get_timestamp)","epoch":$end_time,"level":"PERFORMANCE","operation":"$escaped_operation","duration_seconds":$duration,"script":"${BASH_SOURCE[1]##*/}","pid":$$}
EOF
  else
    log "Operation '$operation' completed in ${duration}s"
  fi
}

# Export format for child processes
export LOG_FORMAT

