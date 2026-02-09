#!/bin/bash

# Session Management Library for Super-Ralph
# Handles Claude session persistence, expiry, and tracking

# Requires these globals from caller:
#   CLAUDE_SESSION_FILE, RALPH_SESSION_FILE, CLAUDE_SESSION_EXPIRY_HOURS
#   get_iso_timestamp()

# Source logging if not already available
if ! declare -f log_status &>/dev/null; then
    SESSION_MGR_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$SESSION_MGR_DIR/logging.sh"
fi

get_session_file_age_hours() {
    local file=$1
    [[ ! -f "$file" ]] && echo "0" && return

    local file_mtime
    if file_mtime=$(stat -c %Y "$file" 2>/dev/null) && [[ -n "$file_mtime" && "$file_mtime" =~ ^[0-9]+$ ]]; then
        : # GNU stat
    elif file_mtime=$(stat -f %m "$file" 2>/dev/null) && [[ -n "$file_mtime" && "$file_mtime" =~ ^[0-9]+$ ]]; then
        : # BSD stat
    elif file_mtime=$(date -r "$file" +%s 2>/dev/null) && [[ -n "$file_mtime" && "$file_mtime" =~ ^[0-9]+$ ]]; then
        : # date -r fallback
    else
        file_mtime=""
    fi

    if [[ -z "$file_mtime" || "$file_mtime" == "0" ]]; then
        echo "-1"
        return
    fi

    local current_time
    current_time=$(date +%s)
    local age_hours=$(((current_time - file_mtime) / 3600))
    echo "$age_hours"
}

init_claude_session() {
    if [[ -f "$CLAUDE_SESSION_FILE" ]]; then
        local age_hours
        age_hours=$(get_session_file_age_hours "$CLAUDE_SESSION_FILE")

        if [[ $age_hours -eq -1 ]]; then
            log_status "WARN" "Could not determine session age, starting new session"
            rm -f "$CLAUDE_SESSION_FILE"
            echo ""
            return 0
        fi

        if [[ $age_hours -ge $CLAUDE_SESSION_EXPIRY_HOURS ]]; then
            log_status "INFO" "Session expired (${age_hours}h old, max ${CLAUDE_SESSION_EXPIRY_HOURS}h), starting new session"
            rm -f "$CLAUDE_SESSION_FILE"
            echo ""
            return 0
        fi

        local session_id
        session_id=$(cat "$CLAUDE_SESSION_FILE" 2>/dev/null)
        if [[ -n "$session_id" ]]; then
            log_status "INFO" "Resuming Claude session: ${session_id:0:20}... (${age_hours}h old)"
            echo "$session_id"
            return 0
        fi
    fi

    log_status "INFO" "Starting new Claude session"
    echo ""
}

save_claude_session() {
    local output_file=$1
    if [[ -f "$output_file" ]]; then
        local session_id
        session_id=$(jq -r '.metadata.session_id // .session_id // empty' "$output_file" 2>/dev/null)
        if [[ -n "$session_id" && "$session_id" != "null" ]]; then
            echo "$session_id" > "$CLAUDE_SESSION_FILE"
            log_status "INFO" "Saved Claude session: ${session_id:0:20}..."
        fi
    fi
}

init_session_tracking() {
    if [[ ! -f "$RALPH_SESSION_FILE" ]]; then
        jq -n \
            --arg session_id "" \
            --arg created_at "$(get_iso_timestamp)" \
            --arg last_used "$(get_iso_timestamp)" \
            '{session_id: $session_id, created_at: $created_at, last_used: $last_used}' \
            > "$RALPH_SESSION_FILE"
    fi
}

update_session_last_used() {
    if [[ -f "$RALPH_SESSION_FILE" ]]; then
        local tmp
        tmp=$(jq --arg ts "$(get_iso_timestamp)" '.last_used = $ts' "$RALPH_SESSION_FILE" 2>/dev/null)
        if [[ -n "$tmp" ]]; then
            echo "$tmp" > "$RALPH_SESSION_FILE"
        fi
    fi
}

reset_session() {
    local reason=${1:-"manual_reset"}
    jq -n \
        --arg reset_at "$(get_iso_timestamp)" \
        --arg reset_reason "$reason" \
        '{session_id: "", created_at: "", last_used: "", reset_at: $reset_at, reset_reason: $reset_reason}' \
        > "$RALPH_SESSION_FILE"
    rm -f "$CLAUDE_SESSION_FILE"
    log_status "INFO" "Session reset: $reason"
}
