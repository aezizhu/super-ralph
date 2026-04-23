#!/usr/bin/env bash

# log_utils.sh - Log rotation for Super-Ralph
# Adapted from upstream ralph-claude-code lib/log_utils.sh (commit 56b2c3e).
# Super-Ralph doesn't maintain a single ralph.log; it writes one
# claude_output_YYYY-MM-DD_HH-MM-SS.log (and companion *_stream.log /
# claude_stderr_*.log) per loop iteration. Rotating that directory by age
# fits Super-Ralph's layout better than the upstream .log.1..4 scheme.

# Requires these globals from caller:
#   LOG_DIR

# Default retention: keep claude_output / stderr / stream logs for N days.
# Override with SUPER_RALPH_LOG_RETENTION_DAYS in the environment or .ralphrc.
SUPER_RALPH_LOG_RETENTION_DAYS="${SUPER_RALPH_LOG_RETENTION_DAYS:-7}"

# Rotate old per-iteration Claude log files by deleting ones older than
# SUPER_RALPH_LOG_RETENTION_DAYS days. Safe no-op when LOG_DIR doesn't exist.
# Errors are suppressed so rotation failures never break the loop.
rotate_logs() {
    [[ -n "${LOG_DIR:-}" ]] || return 0
    [[ -d "$LOG_DIR" ]] || return 0

    local days="${SUPER_RALPH_LOG_RETENTION_DAYS:-7}"
    [[ "$days" =~ ^[0-9]+$ ]] || return 0
    [[ "$days" -gt 0 ]] || return 0

    # -mtime +N is portable across GNU and BSD find.
    find "$LOG_DIR" -maxdepth 1 -type f \
        \( -name 'claude_output_*.log' \
           -o -name 'claude_stderr_*.log' \
           -o -name 'claude_output_*_stream.log' \) \
        -mtime +"$days" -delete 2>/dev/null || true
}

export -f rotate_logs
