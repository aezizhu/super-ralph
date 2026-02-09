#!/usr/bin/env bash

# logging.sh - Shared logging utilities for Super-Ralph
# Provides colored console output and file logging

# Colors (only set if not already defined)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
PURPLE="${PURPLE:-\033[0;35m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# Log a message with level and optional file logging
# Usage: log_status "INFO" "message text"
# Levels: INFO, WARN, ERROR, SUCCESS, LOOP, SKILL
log_status() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case $level in
        "INFO")    color=$BLUE ;;
        "WARN")    color=$YELLOW ;;
        "ERROR")   color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "LOOP")    color=$PURPLE ;;
        "SKILL")   color=$CYAN ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}" >&2

    # Write to log file if LOG_DIR is set
    if [[ -n "${LOG_DIR:-}" ]] && [[ -d "$LOG_DIR" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_DIR/super-ralph.log"
    fi
}

# Export for use in subshells
export -f log_status
