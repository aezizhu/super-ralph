#!/usr/bin/env bats

# Tests for super_ralph_loop.sh functions
# Tests validate_allowed_tools, load_ralphrc, should_exit_gracefully

setup() {
    export TEST_DIR="$BATS_TMPDIR/main_loop_test_$$"
    mkdir -p "$TEST_DIR"

    export SUPER_RALPH_DIR="$TEST_DIR/.ralph"
    mkdir -p "$SUPER_RALPH_DIR"

    export EXIT_SIGNALS_FILE="$SUPER_RALPH_DIR/.exit_signals"
    export RESPONSE_ANALYSIS_FILE="$SUPER_RALPH_DIR/.response_analysis"
    export CLAUDE_SESSION_FILE="$SUPER_RALPH_DIR/.claude_session_id"
    export RALPH_SESSION_FILE="$SUPER_RALPH_DIR/.ralph_session"
    export METHODOLOGY_FILE="$SUPER_RALPH_DIR/.methodology_state"
    export RALPHRC_FILE="$TEST_DIR/.ralphrc"

    export MAX_CALLS_PER_HOUR=100
    export CLAUDE_TIMEOUT_MINUTES=15
    export CLAUDE_OUTPUT_FORMAT="json"
    export CLAUDE_ALLOWED_TOOLS="Write,Read"
    export CLAUDE_USE_CONTINUE="true"
    export CLAUDE_SESSION_EXPIRY_HOURS=24
    export VERBOSE_PROGRESS="false"
    export MAX_CONSECUTIVE_TEST_LOOPS=3
    export MAX_CONSECUTIVE_DONE_SIGNALS=2
    export MAX_LOOP_CONTEXT_LENGTH=800

    # Save env state vars (load_ralphrc uses these)
    export _env_MAX_CALLS_PER_HOUR=""
    export _env_CLAUDE_TIMEOUT_MINUTES=""
    export _env_CLAUDE_OUTPUT_FORMAT=""
    export _env_CLAUDE_ALLOWED_TOOLS=""
    export _env_CLAUDE_USE_CONTINUE=""
    export _env_CLAUDE_SESSION_EXPIRY_HOURS=""
    export _env_VERBOSE_PROGRESS=""
    export _env_MAX_CONSECUTIVE_TEST_LOOPS=""
    export _env_MAX_CONSECUTIVE_DONE_SIGNALS=""

    # Stub functions used by the main loop
    log_status() { :; }
    get_iso_timestamp() { date -u +"%Y-%m-%dT%H:%M:%S+00:00"; }
    get_epoch_seconds() { date +%s; }
    get_next_hour_time() { echo "00:00:00"; }
    export -f log_status get_iso_timestamp get_epoch_seconds get_next_hour_time

    # Source the main loop (will source its own dependencies)
    source "$BATS_TEST_DIRNAME/../standalone/lib/gate_utils.sh"
    source "$BATS_TEST_DIRNAME/../standalone/lib/skill_selector.sh"
    source "$BATS_TEST_DIRNAME/../standalone/lib/tdd_gate.sh"
    source "$BATS_TEST_DIRNAME/../standalone/lib/verification_gate.sh"
    source "$BATS_TEST_DIRNAME/../standalone/lib/session_manager.sh"
    source "$BATS_TEST_DIRNAME/../standalone/lib/exit_detector.sh"

    VALID_TOOL_PATTERNS=(
        "Write" "Read" "Edit" "MultiEdit" "Glob" "Grep"
        "Task" "TodoWrite" "WebFetch" "WebSearch" "Bash"
        "Bash(git *)" "Bash(npm *)" "Bash(bats *)"
        "Bash(python *)" "Bash(node *)" "NotebookEdit"
    )
    RALPHRC_LOADED=false
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# validate_allowed_tools tests
# ============================================================================

# We need to define the function since we can't source the full loop
_define_validate() {
    validate_allowed_tools() {
        local tools_input=$1
        [[ -z "$tools_input" ]] && return 0

        local IFS=','
        read -ra tools <<< "$tools_input"

        for tool in "${tools[@]}"; do
            tool=$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -z "$tool" ]] && continue

            local valid=false
            for pattern in "${VALID_TOOL_PATTERNS[@]}"; do
                if [[ "$tool" == "$pattern" ]]; then
                    valid=true
                    break
                fi
                if [[ "$tool" =~ ^Bash\(.+\)$ ]]; then
                    valid=true
                    break
                fi
            done

            if [[ "$valid" == "false" ]]; then
                echo "Error: Invalid tool in --allowed-tools: '$tool'"
                echo "Valid tools: ${VALID_TOOL_PATTERNS[*]}"
                return 1
            fi
        done
        return 0
    }
}

@test "validate_allowed_tools: accepts empty input" {
    _define_validate
    run validate_allowed_tools ""
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts valid single tool" {
    _define_validate
    run validate_allowed_tools "Write"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts valid comma-separated tools" {
    _define_validate
    run validate_allowed_tools "Write,Read,Edit"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts Bash with patterns" {
    _define_validate
    run validate_allowed_tools "Bash(git *),Bash(npm *)"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts custom Bash patterns" {
    _define_validate
    run validate_allowed_tools "Bash(cargo test)"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: rejects unknown tool" {
    _define_validate
    run validate_allowed_tools "MagicTool"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid tool"* ]]
}

@test "validate_allowed_tools: rejects mixed valid and invalid" {
    _define_validate
    run validate_allowed_tools "Write,FakeTool,Read"
    [ "$status" -eq 1 ]
}

@test "validate_allowed_tools: handles whitespace in tool list" {
    _define_validate
    run validate_allowed_tools "Write , Read , Edit"
    [ "$status" -eq 0 ]
}

# ============================================================================
# load_ralphrc tests
# ============================================================================

_define_load_ralphrc() {
    load_ralphrc() {
        if [[ ! -f "$RALPHRC_FILE" ]]; then
            return 0
        fi

        # shellcheck source=/dev/null
        source "$RALPHRC_FILE"

        [[ -n "${ALLOWED_TOOLS:-}" ]] && CLAUDE_ALLOWED_TOOLS="$ALLOWED_TOOLS"
        [[ -n "${SESSION_CONTINUITY:-}" ]] && CLAUDE_USE_CONTINUE="$SESSION_CONTINUITY"
        [[ -n "${SESSION_EXPIRY_HOURS:-}" ]] && CLAUDE_SESSION_EXPIRY_HOURS="$SESSION_EXPIRY_HOURS"
        [[ -n "${RALPH_VERBOSE:-}" ]] && VERBOSE_PROGRESS="$RALPH_VERBOSE"

        [[ -n "$_env_MAX_CALLS_PER_HOUR" ]] && MAX_CALLS_PER_HOUR="$_env_MAX_CALLS_PER_HOUR"
        [[ -n "$_env_CLAUDE_TIMEOUT_MINUTES" ]] && CLAUDE_TIMEOUT_MINUTES="$_env_CLAUDE_TIMEOUT_MINUTES"
        [[ -n "$_env_CLAUDE_OUTPUT_FORMAT" ]] && CLAUDE_OUTPUT_FORMAT="$_env_CLAUDE_OUTPUT_FORMAT"
        [[ -n "$_env_CLAUDE_ALLOWED_TOOLS" ]] && CLAUDE_ALLOWED_TOOLS="$_env_CLAUDE_ALLOWED_TOOLS"
        [[ -n "$_env_CLAUDE_USE_CONTINUE" ]] && CLAUDE_USE_CONTINUE="$_env_CLAUDE_USE_CONTINUE"
        [[ -n "$_env_CLAUDE_SESSION_EXPIRY_HOURS" ]] && CLAUDE_SESSION_EXPIRY_HOURS="$_env_CLAUDE_SESSION_EXPIRY_HOURS"
        [[ -n "$_env_VERBOSE_PROGRESS" ]] && VERBOSE_PROGRESS="$_env_VERBOSE_PROGRESS"
        [[ -n "$_env_MAX_CONSECUTIVE_TEST_LOOPS" ]] && MAX_CONSECUTIVE_TEST_LOOPS="$_env_MAX_CONSECUTIVE_TEST_LOOPS"
        [[ -n "$_env_MAX_CONSECUTIVE_DONE_SIGNALS" ]] && MAX_CONSECUTIVE_DONE_SIGNALS="$_env_MAX_CONSECUTIVE_DONE_SIGNALS"

        RALPHRC_LOADED=true
        return 0
    }
}

@test "load_ralphrc: returns 0 when no file exists" {
    _define_load_ralphrc
    rm -f "$RALPHRC_FILE"
    run load_ralphrc
    [ "$status" -eq 0 ]
}

@test "load_ralphrc: sets RALPHRC_LOADED on success" {
    _define_load_ralphrc
    echo 'MAX_CALLS_PER_HOUR=50' > "$RALPHRC_FILE"
    load_ralphrc
    [ "$RALPHRC_LOADED" = "true" ]
}

@test "load_ralphrc: reads MAX_CALLS_PER_HOUR from config" {
    _define_load_ralphrc
    echo 'MAX_CALLS_PER_HOUR=42' > "$RALPHRC_FILE"
    load_ralphrc
    [ "$MAX_CALLS_PER_HOUR" = "42" ]
}

@test "load_ralphrc: maps ALLOWED_TOOLS to CLAUDE_ALLOWED_TOOLS" {
    _define_load_ralphrc
    echo 'ALLOWED_TOOLS="Write,Read"' > "$RALPHRC_FILE"
    load_ralphrc
    [ "$CLAUDE_ALLOWED_TOOLS" = "Write,Read" ]
}

@test "load_ralphrc: env var overrides ralphrc value" {
    _define_load_ralphrc
    echo 'MAX_CALLS_PER_HOUR=50' > "$RALPHRC_FILE"
    _env_MAX_CALLS_PER_HOUR=200
    load_ralphrc
    [ "$MAX_CALLS_PER_HOUR" = "200" ]
    _env_MAX_CALLS_PER_HOUR=""
}

@test "load_ralphrc: maps SESSION_CONTINUITY to CLAUDE_USE_CONTINUE" {
    _define_load_ralphrc
    echo 'SESSION_CONTINUITY=false' > "$RALPHRC_FILE"
    load_ralphrc
    [ "$CLAUDE_USE_CONTINUE" = "false" ]
}

# ============================================================================
# should_exit_gracefully tests
# ============================================================================

@test "should_exit_gracefully: returns empty when no exit signals file" {
    rm -f "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "should_exit_gracefully: returns empty with zero signals" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "should_exit_gracefully: detects test saturation" {
    echo '{"test_only_loops": [1,2,3], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "test_saturation" ]
}

@test "should_exit_gracefully: detects completion signals" {
    echo '{"test_only_loops": [], "done_signals": [1,2], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "completion_signals" ]
}

@test "should_exit_gracefully: detects safety circuit breaker" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": [1,2,3,4,5]}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "safety_circuit_breaker" ]
}

@test "should_exit_gracefully: detects permission denied" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"has_permission_denials": true, "denied_commands": ["git push"]}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "permission_denied" ]
}

@test "should_exit_gracefully: returns plan_complete when all tasks done" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    # Create a fix_plan with all tasks checked
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
- [x] Task 1
- [x] Task 2
EOF
    result=$(should_exit_gracefully)
    [ "$result" = "plan_complete" ]
}

# ============================================================================
# validate_ralphrc tests (NEW - to be implemented)
# ============================================================================

@test "validate_ralphrc: accepts valid numeric MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR=50
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: rejects non-numeric MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR="abc"
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"MAX_CALLS_PER_HOUR"* ]]
}

@test "validate_ralphrc: rejects non-numeric CLAUDE_TIMEOUT_MINUTES" {
    CLAUDE_TIMEOUT_MINUTES="xyz"
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"CLAUDE_TIMEOUT_MINUTES"* ]]
}

@test "validate_ralphrc: accepts valid CLAUDE_OUTPUT_FORMAT" {
    CLAUDE_OUTPUT_FORMAT="json"
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: rejects invalid CLAUDE_OUTPUT_FORMAT" {
    CLAUDE_OUTPUT_FORMAT="xml"
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"CLAUDE_OUTPUT_FORMAT"* ]]
}

@test "validate_ralphrc: rejects negative CLAUDE_SESSION_EXPIRY_HOURS" {
    CLAUDE_SESSION_EXPIRY_HOURS="-1"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}
