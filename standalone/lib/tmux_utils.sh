#!/bin/bash

# TMUX Utilities for Super-Ralph
# Sets up multi-pane monitoring sessions

# Requires these globals from caller:
#   SCRIPT_DIR, SUPER_RALPH_DIR, LIVE_LOG_FILE, STATUS_FILE
#   MAX_CALLS_PER_HOUR, PROMPT_FILE, CLAUDE_OUTPUT_FORMAT
#   VERBOSE_PROGRESS, CLAUDE_TIMEOUT_MINUTES, CLAUDE_USE_CONTINUE
#   CLAUDE_SESSION_EXPIRY_HOURS
#   log_status()

check_tmux_available() {
    if ! command -v tmux &>/dev/null; then
        log_status "ERROR" "tmux is not installed."
        echo "Install tmux: brew install tmux (macOS) or sudo apt-get install tmux (Linux)"
        exit 1
    fi
}

setup_tmux_session() {
    local session_name
    session_name="super-ralph-$(date +%s)"
    local project_dir
    project_dir=$(pwd)
    local base_win
    base_win=$(tmux show-options -gv base-index 2>/dev/null)
    base_win="${base_win:-0}"

    log_status "INFO" "Setting up tmux session: $session_name"
    echo "=== Super-Ralph Live Output - Waiting for first loop... ===" > "$LIVE_LOG_FILE"

    tmux new-session -d -s "$session_name" -c "$project_dir"
    tmux split-window -h -t "$session_name" -c "$project_dir"
    tmux split-window -v -t "$session_name:${base_win}.1" -c "$project_dir"

    # Right-top: live Claude output
    tmux send-keys -t "$session_name:${base_win}.1" "tail -f '$project_dir/$LIVE_LOG_FILE'" Enter
    # Right-bottom: status monitor
    tmux send-keys -t "$session_name:${base_win}.2" "watch -n 5 'jq . $project_dir/$STATUS_FILE 2>/dev/null || echo No status yet'" Enter

    # Left: super-ralph loop (forward relevant args, always use --live in tmux)
    local sr_cmd="'$SCRIPT_DIR/super_ralph_loop.sh' --live"
    [[ "$MAX_CALLS_PER_HOUR" != "100" ]] && sr_cmd="$sr_cmd --calls $MAX_CALLS_PER_HOUR"
    [[ "$PROMPT_FILE" != "$SUPER_RALPH_DIR/PROMPT.md" ]] && sr_cmd="$sr_cmd --prompt '$PROMPT_FILE'"
    [[ "$CLAUDE_OUTPUT_FORMAT" != "json" ]] && sr_cmd="$sr_cmd --output-format $CLAUDE_OUTPUT_FORMAT"
    [[ "$VERBOSE_PROGRESS" == "true" ]] && sr_cmd="$sr_cmd --verbose"
    [[ "$CLAUDE_TIMEOUT_MINUTES" != "15" ]] && sr_cmd="$sr_cmd --timeout $CLAUDE_TIMEOUT_MINUTES"
    [[ "$CLAUDE_USE_CONTINUE" == "false" ]] && sr_cmd="$sr_cmd --no-continue"
    [[ "$CLAUDE_SESSION_EXPIRY_HOURS" != "24" ]] && sr_cmd="$sr_cmd --session-expiry $CLAUDE_SESSION_EXPIRY_HOURS"

    tmux send-keys -t "$session_name:${base_win}.0" "$sr_cmd" Enter
    tmux select-pane -t "$session_name:${base_win}.0"
    tmux select-pane -t "$session_name:${base_win}.0" -T "Super-Ralph Loop"
    tmux select-pane -t "$session_name:${base_win}.1" -T "Claude Output"
    tmux select-pane -t "$session_name:${base_win}.2" -T "Status"
    tmux rename-window -t "$session_name:${base_win}" "Super-Ralph: Loop | Output | Status"

    log_status "SUCCESS" "Tmux session created with 3 panes:"
    log_status "INFO" "  Left:         Super-Ralph loop"
    log_status "INFO" "  Right-top:    Claude Code live output"
    log_status "INFO" "  Right-bottom: Status monitor"
    log_status "INFO" "Use Ctrl+B then D to detach, 'tmux attach -t $session_name' to reattach"

    tmux attach-session -t "$session_name"
    exit 0
}
