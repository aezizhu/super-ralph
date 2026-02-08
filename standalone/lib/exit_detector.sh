#!/bin/bash

# Exit Detector Library for Super-Ralph
# Determines when the loop should stop based on signal analysis

# Requires these globals from caller:
#   EXIT_SIGNALS_FILE, RESPONSE_ANALYSIS_FILE
#   MAX_CONSECUTIVE_TEST_LOOPS, MAX_CONSECUTIVE_DONE_SIGNALS
#   log_status(), all_tasks_complete(), validate_exit_signal()

should_exit_gracefully() {
    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        echo ""
        return
    fi

    local signals
    signals=$(cat "$EXIT_SIGNALS_FILE")

    local recent_test_loops
    recent_test_loops=$(echo "$signals" | jq '.test_only_loops | length' 2>/dev/null || echo "0")
    local recent_done_signals
    recent_done_signals=$(echo "$signals" | jq '.done_signals | length' 2>/dev/null || echo "0")
    local recent_completion_indicators
    recent_completion_indicators=$(echo "$signals" | jq '.completion_indicators | length' 2>/dev/null || echo "0")

    # Permission denial detection
    if [[ -f "$RESPONSE_ANALYSIS_FILE" ]]; then
        local has_permission_denials
        has_permission_denials=$(jq -r '.analysis.has_permission_denials // false' "$RESPONSE_ANALYSIS_FILE" 2>/dev/null || echo "false")
        if [[ "$has_permission_denials" == "true" ]]; then
            local denied_cmds
            denied_cmds=$(jq -r '.analysis.denied_commands | join(", ")' "$RESPONSE_ANALYSIS_FILE" 2>/dev/null || echo "unknown")
            log_status "WARN" "Permission denied for commands: $denied_cmds"
            echo "permission_denied"
            return
        fi
    fi

    # Too many consecutive test-only loops
    if [[ $recent_test_loops -ge $MAX_CONSECUTIVE_TEST_LOOPS ]]; then
        echo "test_saturation"
        return
    fi

    # Multiple done signals
    if [[ $recent_done_signals -ge $MAX_CONSECUTIVE_DONE_SIGNALS ]]; then
        echo "completion_signals"
        return
    fi

    # Safety circuit breaker (5+ consecutive EXIT_SIGNAL=true)
    if [[ $recent_completion_indicators -ge 5 ]]; then
        log_status "WARN" "SAFETY CIRCUIT BREAKER: Force exit after 5 consecutive EXIT_SIGNAL=true"
        echo "safety_circuit_breaker"
        return
    fi

    # Strong completion + EXIT_SIGNAL=true from Claude
    local claude_exit_signal="false"
    if [[ -f "$RESPONSE_ANALYSIS_FILE" ]]; then
        claude_exit_signal=$(jq -r '.analysis.exit_signal // false' "$RESPONSE_ANALYSIS_FILE" 2>/dev/null || echo "false")
    fi

    if [[ $recent_completion_indicators -ge 2 ]] && [[ "$claude_exit_signal" == "true" ]]; then
        echo "project_complete"
        return
    fi

    # Verification gate on exit signal
    if all_tasks_complete 2>/dev/null; then
        if [[ "$claude_exit_signal" == "true" ]]; then
            local verified
            verified=$(validate_exit_signal "$RESPONSE_ANALYSIS_FILE")
            if [[ "$verified" == "true" ]]; then
                echo "project_complete_verified"
                return
            else
                log_status "WARN" "EXIT_SIGNAL=true but verification gate failed - continuing"
            fi
        fi
        echo "plan_complete"
        return
    fi

    echo ""
}

# Validate configuration values after loading .ralphrc
validate_ralphrc() {
    local errors=0

    if [[ -n "$MAX_CALLS_PER_HOUR" ]] && [[ ! "$MAX_CALLS_PER_HOUR" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: MAX_CALLS_PER_HOUR must be a positive integer (got: '$MAX_CALLS_PER_HOUR')"
        errors=$((errors + 1))
    fi

    if [[ -n "$CLAUDE_TIMEOUT_MINUTES" ]] && [[ ! "$CLAUDE_TIMEOUT_MINUTES" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: CLAUDE_TIMEOUT_MINUTES must be a positive integer (got: '$CLAUDE_TIMEOUT_MINUTES')"
        errors=$((errors + 1))
    fi

    if [[ -n "$CLAUDE_OUTPUT_FORMAT" ]] && [[ "$CLAUDE_OUTPUT_FORMAT" != "json" && "$CLAUDE_OUTPUT_FORMAT" != "text" ]]; then
        echo "Error: CLAUDE_OUTPUT_FORMAT must be 'json' or 'text' (got: '$CLAUDE_OUTPUT_FORMAT')"
        errors=$((errors + 1))
    fi

    if [[ -n "$CLAUDE_SESSION_EXPIRY_HOURS" ]] && [[ ! "$CLAUDE_SESSION_EXPIRY_HOURS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: CLAUDE_SESSION_EXPIRY_HOURS must be a positive integer (got: '$CLAUDE_SESSION_EXPIRY_HOURS')"
        errors=$((errors + 1))
    fi

    if [[ -n "$MAX_CONSECUTIVE_TEST_LOOPS" ]] && [[ ! "$MAX_CONSECUTIVE_TEST_LOOPS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: MAX_CONSECUTIVE_TEST_LOOPS must be a positive integer (got: '$MAX_CONSECUTIVE_TEST_LOOPS')"
        errors=$((errors + 1))
    fi

    if [[ -n "$MAX_CONSECUTIVE_DONE_SIGNALS" ]] && [[ ! "$MAX_CONSECUTIVE_DONE_SIGNALS" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: MAX_CONSECUTIVE_DONE_SIGNALS must be a positive integer (got: '$MAX_CONSECUTIVE_DONE_SIGNALS')"
        errors=$((errors + 1))
    fi

    [[ $errors -gt 0 ]] && return 1
    return 0
}
