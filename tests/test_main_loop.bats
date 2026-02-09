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

@test "validate_allowed_tools: accepts MultiEdit" {
    _define_validate
    run validate_allowed_tools "MultiEdit"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts Glob and Grep" {
    _define_validate
    run validate_allowed_tools "Glob,Grep"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts Task and TodoWrite" {
    _define_validate
    run validate_allowed_tools "Task,TodoWrite"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts WebFetch and WebSearch" {
    _define_validate
    run validate_allowed_tools "WebFetch,WebSearch"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts NotebookEdit" {
    _define_validate
    run validate_allowed_tools "NotebookEdit"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts Bash(bats *)" {
    _define_validate
    run validate_allowed_tools "Bash(bats *)"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts Bash(python *) and Bash(node *)" {
    _define_validate
    run validate_allowed_tools "Bash(python *),Bash(node *)"
    [ "$status" -eq 0 ]
}

@test "validate_allowed_tools: accepts all tools combined" {
    _define_validate
    run validate_allowed_tools "Write,Read,Edit,MultiEdit,Glob,Grep,Task,TodoWrite,WebFetch,WebSearch,Bash,NotebookEdit"
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

# ============================================================================
# Rate limiting function tests
# ============================================================================

_define_rate_limiting() {
    CALL_COUNT_FILE="$SUPER_RALPH_DIR/.call_count"
    TIMESTAMP_FILE="$SUPER_RALPH_DIR/.last_reset"

    init_call_tracking() {
        local current_hour
        current_hour=$(date +%Y%m%d%H)
        local last_reset_hour=""
        if [[ -f "$TIMESTAMP_FILE" ]]; then
            last_reset_hour=$(cat "$TIMESTAMP_FILE")
        fi
        if [[ "$current_hour" != "$last_reset_hour" ]]; then
            echo "0" > "$CALL_COUNT_FILE"
            echo "$current_hour" > "$TIMESTAMP_FILE"
        fi
        if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
            echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
        fi
    }

    can_make_call() {
        local calls_made=0
        if [[ -f "$CALL_COUNT_FILE" ]]; then
            calls_made=$(cat "$CALL_COUNT_FILE")
        fi
        [[ $calls_made -lt $MAX_CALLS_PER_HOUR ]]
    }

    increment_call_counter() {
        local calls_made=0
        if [[ -f "$CALL_COUNT_FILE" ]]; then
            calls_made=$(cat "$CALL_COUNT_FILE")
        fi
        ((calls_made++))
        echo "$calls_made" > "$CALL_COUNT_FILE"
        echo "$calls_made"
    }

    update_status() {
        local loop_count=$1
        local calls_made=$2
        local last_action=$3
        local status=$4
        local exit_reason=${5:-""}
        STATUS_FILE="$SUPER_RALPH_DIR/status.json"
        cat > "$STATUS_FILE" << STATUSEOF
{
    "timestamp": "$(get_iso_timestamp)",
    "loop_count": $loop_count,
    "calls_made_this_hour": $calls_made,
    "max_calls_per_hour": $MAX_CALLS_PER_HOUR,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason",
    "next_reset": "$(get_next_hour_time)",
    "mode": "super-ralph"
}
STATUSEOF
    }
}

@test "init_call_tracking: creates call count file" {
    _define_rate_limiting
    rm -f "$CALL_COUNT_FILE" "$TIMESTAMP_FILE"
    init_call_tracking
    [ -f "$CALL_COUNT_FILE" ]
    result=$(cat "$CALL_COUNT_FILE")
    [ "$result" = "0" ]
}

@test "init_call_tracking: creates exit signals file" {
    _define_rate_limiting
    rm -f "$EXIT_SIGNALS_FILE"
    init_call_tracking
    [ -f "$EXIT_SIGNALS_FILE" ]
    jq -e '.test_only_loops' "$EXIT_SIGNALS_FILE" >/dev/null
}

@test "init_call_tracking: preserves count within same hour" {
    _define_rate_limiting
    echo "42" > "$CALL_COUNT_FILE"
    date +%Y%m%d%H > "$TIMESTAMP_FILE"
    init_call_tracking
    result=$(cat "$CALL_COUNT_FILE")
    [ "$result" = "42" ]
}

@test "can_make_call: true when under limit" {
    _define_rate_limiting
    echo "5" > "$CALL_COUNT_FILE"
    MAX_CALLS_PER_HOUR=100
    run can_make_call
    [ "$status" -eq 0 ]
}

@test "can_make_call: false when at limit" {
    _define_rate_limiting
    echo "100" > "$CALL_COUNT_FILE"
    MAX_CALLS_PER_HOUR=100
    run can_make_call
    [ "$status" -eq 1 ]
}

@test "can_make_call: true when no count file" {
    _define_rate_limiting
    rm -f "$CALL_COUNT_FILE"
    MAX_CALLS_PER_HOUR=100
    run can_make_call
    [ "$status" -eq 0 ]
}

@test "increment_call_counter: increments from 0" {
    _define_rate_limiting
    echo "0" > "$CALL_COUNT_FILE"
    result=$(increment_call_counter)
    [ "$result" = "1" ]
    file_val=$(cat "$CALL_COUNT_FILE")
    [ "$file_val" = "1" ]
}

@test "increment_call_counter: increments from existing count" {
    _define_rate_limiting
    echo "10" > "$CALL_COUNT_FILE"
    result=$(increment_call_counter)
    [ "$result" = "11" ]
}

@test "increment_call_counter: handles missing file" {
    _define_rate_limiting
    rm -f "$CALL_COUNT_FILE"
    result=$(increment_call_counter)
    [ "$result" = "1" ]
}

@test "update_status: creates valid JSON status file" {
    _define_rate_limiting
    update_status 5 10 "executing" "running"
    [ -f "$SUPER_RALPH_DIR/status.json" ]
    local loop_count
    loop_count=$(jq '.loop_count' "$SUPER_RALPH_DIR/status.json")
    [ "$loop_count" = "5" ]
    local status_val
    status_val=$(jq -r '.status' "$SUPER_RALPH_DIR/status.json")
    [ "$status_val" = "running" ]
}

@test "update_status: includes exit reason when provided" {
    _define_rate_limiting
    update_status 3 5 "graceful_exit" "completed" "project_complete"
    local reason
    reason=$(jq -r '.exit_reason' "$SUPER_RALPH_DIR/status.json")
    [ "$reason" = "project_complete" ]
}

@test "update_status: mode is super-ralph" {
    _define_rate_limiting
    update_status 1 0 "starting" "running"
    local mode
    mode=$(jq -r '.mode' "$SUPER_RALPH_DIR/status.json")
    [ "$mode" = "super-ralph" ]
}

# ============================================================================
# detect_project_tools tests
# ============================================================================

_define_detect_project_tools() {
    detect_project_tools() {
        local base_tools="Write,Read,Edit,Bash(git *)"
        local detected_tools=""

        if [[ -f "package.json" ]]; then
            detected_tools+=",Bash(npm *),Bash(npx *),Bash(node *)"
            [[ -f "yarn.lock" ]] && detected_tools+=",Bash(yarn *)"
            [[ -f "pnpm-lock.yaml" ]] && detected_tools+=",Bash(pnpm *)"
            if [[ -f "bun.lockb" ]] || [[ -f "bunfig.toml" ]]; then
                detected_tools+=",Bash(bun *)"
            fi
        fi
        if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "setup.cfg" ]] || [[ -f "Pipfile" ]] || [[ -f "requirements.txt" ]]; then
            detected_tools+=",Bash(python *),Bash(python3 *),Bash(pip *),Bash(pytest *)"
            [[ -f "Pipfile" ]] && detected_tools+=",Bash(pipenv *)"
            if [[ -f "poetry.lock" ]] || grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
                detected_tools+=",Bash(poetry *)"
            fi
            [[ -f "uv.lock" ]] && detected_tools+=",Bash(uv *)"
        fi
        if [[ -f "Cargo.toml" ]]; then
            detected_tools+=",Bash(cargo *),Bash(rustc *)"
        fi
        if [[ -f "go.mod" ]]; then
            detected_tools+=",Bash(go *)"
        fi
        if [[ -f "pom.xml" ]]; then
            detected_tools+=",Bash(mvn *),Bash(java *)"
        fi
        if [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; then
            detected_tools+=",Bash(gradle *),Bash(./gradlew *),Bash(java *)"
        fi
        if [[ -f "Gemfile" ]]; then
            detected_tools+=",Bash(ruby *),Bash(bundle *),Bash(rake *),Bash(rspec *)"
        fi
        if [[ -f "mix.exs" ]]; then
            detected_tools+=",Bash(mix *),Bash(elixir *),Bash(iex *)"
        fi
        if [[ -f "composer.json" ]]; then
            detected_tools+=",Bash(php *),Bash(composer *),Bash(phpunit *)"
        fi
        if ls ./*.csproj &>/dev/null || ls ./*.sln &>/dev/null || [[ -f "global.json" ]]; then
            detected_tools+=",Bash(dotnet *)"
        fi
        detected_tools+=",Bash(bats *)"
        if [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
            detected_tools+=",Bash(docker *),Bash(docker-compose *)"
        fi
        if [[ -f "Makefile" ]]; then
            detected_tools+=",Bash(make *)"
        fi

        echo "${base_tools}${detected_tools}"
    }
}

@test "detect_project_tools: base tools always present" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    result=$(detect_project_tools)
    [[ "$result" == *"Write,Read,Edit,Bash(git *)"* ]]
}

@test "detect_project_tools: detects Node.js from package.json" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch package.json
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(npm *)"* ]]
    [[ "$result" == *"Bash(node *)"* ]]
}

@test "detect_project_tools: detects Python from pyproject.toml" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch pyproject.toml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(python *)"* ]]
    [[ "$result" == *"Bash(pytest *)"* ]]
}

@test "detect_project_tools: detects Rust from Cargo.toml" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch Cargo.toml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(cargo *)"* ]]
}

@test "detect_project_tools: detects Go from go.mod" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch go.mod
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(go *)"* ]]
}

@test "detect_project_tools: detects Ruby from Gemfile" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch Gemfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(ruby *)"* ]]
    [[ "$result" == *"Bash(bundle *)"* ]]
}

@test "detect_project_tools: detects Elixir from mix.exs" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch mix.exs
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(mix *)"* ]]
    [[ "$result" == *"Bash(elixir *)"* ]]
    [[ "$result" == *"Bash(iex *)"* ]]
}

@test "detect_project_tools: detects PHP from composer.json" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch composer.json
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(php *)"* ]]
    [[ "$result" == *"Bash(composer *)"* ]]
    [[ "$result" == *"Bash(phpunit *)"* ]]
}

@test "detect_project_tools: detects .NET from csproj" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch app.csproj
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(dotnet *)"* ]]
}

@test "detect_project_tools: detects .NET from global.json" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch global.json
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(dotnet *)"* ]]
}

@test "detect_project_tools: detects Docker" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch Dockerfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(docker *)"* ]]
}

@test "detect_project_tools: detects Make" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch Makefile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(make *)"* ]]
}

@test "detect_project_tools: detects yarn lockfile" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    touch package.json yarn.lock
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(yarn *)"* ]]
}

@test "detect_project_tools: always includes bats" {
    _define_detect_project_tools
    local project_dir="$TEST_DIR/detect_test"
    mkdir -p "$project_dir" && cd "$project_dir"
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(bats *)"* ]]
}

# ============================================================================
# count_changed_files tests
# ============================================================================

_define_count_changed_files() {
    count_changed_files() {
        local start_sha="${1:-}"
        local current_sha="${2:-}"

        {
            if [[ -n "$start_sha" && -n "$current_sha" && "$start_sha" != "$current_sha" ]]; then
                git diff --name-only "$start_sha" "$current_sha" 2>/dev/null
            fi
            git diff --name-only 2>/dev/null
            git diff --name-only --cached 2>/dev/null
        } | sort -u | wc -l
    }
}
