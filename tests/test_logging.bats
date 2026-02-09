#!/usr/bin/env bats

# Tests for logging.sh - Shared logging utilities

setup() {
    export TEST_DIR="$BATS_TMPDIR/logging_test_$$"
    mkdir -p "$TEST_DIR"
    export LOG_DIR="$TEST_DIR/logs"
    mkdir -p "$LOG_DIR"
    source "$BATS_TEST_DIRNAME/../standalone/lib/logging.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# log_status tests
# ============================================================================

@test "log_status: outputs message to stderr" {
    run log_status "INFO" "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "log_status: includes level in output" {
    run log_status "WARN" "warning message"
    [[ "$output" == *"[WARN]"* ]]
}

@test "log_status: includes timestamp in output" {
    run log_status "INFO" "timestamped"
    # Match YYYY-MM-DD HH:MM:SS pattern
    [[ "$output" =~ \[20[0-9]{2}-[0-9]{2}-[0-9]{2} ]]
}

@test "log_status: writes to log file when LOG_DIR set" {
    log_status "INFO" "file logged message" 2>/dev/null
    [ -f "$LOG_DIR/super-ralph.log" ]
    grep -q "file logged message" "$LOG_DIR/super-ralph.log"
}

@test "log_status: log file contains level" {
    log_status "ERROR" "error in log" 2>/dev/null
    grep -q "\[ERROR\]" "$LOG_DIR/super-ralph.log"
}

@test "log_status: handles all log levels" {
    for level in INFO WARN ERROR SUCCESS LOOP SKILL; do
        log_status "$level" "testing $level" 2>/dev/null
    done
    [ "$(wc -l < "$LOG_DIR/super-ralph.log")" -eq 6 ]
}

@test "log_status: works without LOG_DIR" {
    unset LOG_DIR
    run log_status "INFO" "no log dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no log dir"* ]]
}

# ============================================================================
# Color constant tests
# ============================================================================

@test "logging: defines color constants" {
    [[ -n "$RED" ]]
    [[ -n "$GREEN" ]]
    [[ -n "$YELLOW" ]]
    [[ -n "$BLUE" ]]
    [[ -n "$PURPLE" ]]
    [[ -n "$CYAN" ]]
    [[ -n "$NC" ]]
}
