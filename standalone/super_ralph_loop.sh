#!/bin/bash

# Super-Ralph Loop - Superpowers-Enhanced Autonomous Development
# Extends Ralph's autonomous loop with disciplined engineering workflows:
# brainstorming, TDD, systematic debugging, code review, verification
#
# Can operate standalone or as a wrapper around Ralph.
# If Ralph is installed, delegates infrastructure to Ralph and adds methodology.
# If Ralph is not installed, runs its own loop with embedded Ralph features.

set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# =============================================================================
# MODE DETECTION: Standalone vs Ralph Extension
# =============================================================================

RALPH_INSTALLED=false
RALPH_HOME="${RALPH_HOME:-$HOME/.ralph}"

if command -v ralph &>/dev/null || [[ -f "$RALPH_HOME/ralph_loop.sh" ]]; then
    RALPH_INSTALLED=true
fi

# =============================================================================
# SOURCE DEPENDENCIES
# =============================================================================

source "$SCRIPT_DIR/lib/skill_selector.sh"
source "$SCRIPT_DIR/lib/tdd_gate.sh"
source "$SCRIPT_DIR/lib/verification_gate.sh"

if [[ "$RALPH_INSTALLED" == "true" ]]; then
    [[ -f "$RALPH_HOME/lib/date_utils.sh" ]] && source "$RALPH_HOME/lib/date_utils.sh"
    [[ -f "$RALPH_HOME/lib/timeout_utils.sh" ]] && source "$RALPH_HOME/lib/timeout_utils.sh"
    [[ -f "$RALPH_HOME/lib/response_analyzer.sh" ]] && source "$RALPH_HOME/lib/response_analyzer.sh"
    [[ -f "$RALPH_HOME/lib/circuit_breaker.sh" ]] && source "$RALPH_HOME/lib/circuit_breaker.sh"
fi

# Standalone fallbacks for when Ralph is not installed
if ! type get_iso_timestamp &>/dev/null 2>&1; then
    get_iso_timestamp() {
        date -u +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\(..\)$/:\1/'
    }
    get_epoch_seconds() { date +%s; }
    get_next_hour_time() {
        date -v+1H '+%H:%M:%S' 2>/dev/null || date -d '+1 hour' '+%H:%M:%S' 2>/dev/null || {
            # Fallback: manually calculate next hour when neither BSD nor GNU date is available
            local current_hour
            current_hour=$(date '+%H')
            local next_hour=$(( (10#$current_hour + 1) % 24 ))
            printf '%02d:00:00' "$next_hour"
        }
    }
    export -f get_iso_timestamp get_epoch_seconds get_next_hour_time
fi

if ! type portable_timeout &>/dev/null 2>&1; then
    portable_timeout() {
        if command -v gtimeout &>/dev/null; then
            gtimeout "$@"
        elif command -v timeout &>/dev/null; then
            timeout "$@"
        else
            # No timeout available - run without it
            shift  # remove the timeout duration arg
            "$@"
        fi
    }
    export -f portable_timeout
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

SUPER_RALPH_DIR=".ralph"
PROMPT_FILE="$SUPER_RALPH_DIR/PROMPT.md"
LOG_DIR="$SUPER_RALPH_DIR/logs"
DOCS_DIR="$SUPER_RALPH_DIR/docs/generated"
STATUS_FILE="$SUPER_RALPH_DIR/status.json"
PROGRESS_FILE="$SUPER_RALPH_DIR/progress.json"
CALL_COUNT_FILE="$SUPER_RALPH_DIR/.call_count"
# A4: cumulative token counter for MAX_TOKENS_PER_HOUR enforcement.
TOKEN_COUNT_FILE="$SUPER_RALPH_DIR/.token_count"
TIMESTAMP_FILE="$SUPER_RALPH_DIR/.last_reset"
EXIT_SIGNALS_FILE="$SUPER_RALPH_DIR/.exit_signals"
RESPONSE_ANALYSIS_FILE="$SUPER_RALPH_DIR/.response_analysis"
METHODOLOGY_FILE="$SUPER_RALPH_DIR/.methodology_state"
# Used by lib/session_manager.sh (sourced below)
# shellcheck disable=SC2034
CLAUDE_SESSION_FILE="$SUPER_RALPH_DIR/.claude_session_id"
# shellcheck disable=SC2034
RALPH_SESSION_FILE="$SUPER_RALPH_DIR/.ralph_session"
LIVE_LOG_FILE="$SUPER_RALPH_DIR/live.log"
RALPHRC_FILE=".ralphrc"

# Save environment variable state BEFORE setting defaults
_env_MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-}"
_env_CLAUDE_TIMEOUT_MINUTES="${CLAUDE_TIMEOUT_MINUTES:-}"
_env_CLAUDE_OUTPUT_FORMAT="${CLAUDE_OUTPUT_FORMAT:-}"
_env_CLAUDE_ALLOWED_TOOLS="${CLAUDE_ALLOWED_TOOLS:-}"
_env_CLAUDE_USE_CONTINUE="${CLAUDE_USE_CONTINUE:-}"
_env_CLAUDE_SESSION_EXPIRY_HOURS="${CLAUDE_SESSION_EXPIRY_HOURS:-}"
_env_VERBOSE_PROGRESS="${VERBOSE_PROGRESS:-}"
_env_MAX_CONSECUTIVE_TEST_LOOPS="${MAX_CONSECUTIVE_TEST_LOOPS:-}"
_env_MAX_CONSECUTIVE_DONE_SIGNALS="${MAX_CONSECUTIVE_DONE_SIGNALS:-}"
# A2/A3: snapshot CLAUDE_CODE_CMD before the default is applied so .ralphrc
# values aren't silently overwritten (upstream b31640a).
_env_CLAUDE_CODE_CMD="${CLAUDE_CODE_CMD:-}"
# A3: model / effort overrides (upstream b31640a).
_env_CLAUDE_MODEL="${CLAUDE_MODEL:-}"
_env_CLAUDE_EFFORT="${CLAUDE_EFFORT:-}"
# A8: notification opt-in (upstream a1f6d5f).
_env_ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-}"
# A4: token-budget alternative rate limit + shell-init file (upstream 8c7a7d9).
_env_MAX_TOKENS_PER_HOUR="${MAX_TOKENS_PER_HOUR:-}"
_env_RALPH_SHELL_INIT_FILE="${RALPH_SHELL_INIT_FILE:-}"
_env_SUPER_RALPH_SHELL_INIT_FILE="${SUPER_RALPH_SHELL_INIT_FILE:-}"
# A9: backup/rollback opt-in (upstream da2f157, e13a3cb).
_env_ENABLE_BACKUP="${ENABLE_BACKUP:-}"

MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-100}"
CLAUDE_TIMEOUT_MINUTES="${CLAUDE_TIMEOUT_MINUTES:-15}"
CLAUDE_OUTPUT_FORMAT="${CLAUDE_OUTPUT_FORMAT:-json}"
CLAUDE_ALLOWED_TOOLS="${CLAUDE_ALLOWED_TOOLS:-__AUTO_DETECT__}"
CLAUDE_USE_CONTINUE="${CLAUDE_USE_CONTINUE:-true}"
CLAUDE_SESSION_EXPIRY_HOURS="${CLAUDE_SESSION_EXPIRY_HOURS:-24}"
# A3: respect CLAUDE_CODE_CMD from .ralphrc / env; previous hardcoded
# "claude" overwrote load_ralphrc's value.
CLAUDE_CODE_CMD="${CLAUDE_CODE_CMD:-claude}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"
CLAUDE_EFFORT="${CLAUDE_EFFORT:-}"
# A5: --dry-run simulates the loop without hitting the Claude API.
DRY_RUN="${DRY_RUN:-false}"
# A8: desktop notifications; off by default. Enable via --notify or
# ENABLE_NOTIFICATIONS=true.
ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-false}"
# A4: cumulative token budget per hour. 0 = disabled (call-count only).
MAX_TOKENS_PER_HOUR="${MAX_TOKENS_PER_HOUR:-0}"
# A4: shell init file sourced before invoking claude. Lets zsh-only users
# pull PATH / env vars from ~/.zshrc. SUPER_RALPH_SHELL_INIT_FILE takes
# precedence over RALPH_SHELL_INIT_FILE (alias retained for familiarity).
SUPER_RALPH_SHELL_INIT_FILE="${SUPER_RALPH_SHELL_INIT_FILE:-}"
RALPH_SHELL_INIT_FILE="${RALPH_SHELL_INIT_FILE:-}"
# A9: backup/rollback opt-in. Defaults false to avoid creating branches in
# shared repos. Enable via --backup or ENABLE_BACKUP=true.
ENABLE_BACKUP="${ENABLE_BACKUP:-false}"
VERBOSE_PROGRESS="${VERBOSE_PROGRESS:-false}"
USE_TMUX=false
LIVE_OUTPUT=false

MAX_CONSECUTIVE_TEST_LOOPS="${MAX_CONSECUTIVE_TEST_LOOPS:-3}"
MAX_CONSECUTIVE_DONE_SIGNALS="${MAX_CONSECUTIVE_DONE_SIGNALS:-2}"
MAX_LOOP_CONTEXT_LENGTH="${MAX_LOOP_CONTEXT_LENGTH:-800}"
PROGRESS_CHECK_INTERVAL="${PROGRESS_CHECK_INTERVAL:-10}"
POST_EXECUTION_PAUSE="${POST_EXECUTION_PAUSE:-5}"
RETRY_BACKOFF_SECONDS="${RETRY_BACKOFF_SECONDS:-30}"
RATE_LIMIT_RETRY_SECONDS="${RATE_LIMIT_RETRY_SECONDS:-3600}"

VALID_TOOL_PATTERNS=(
    "Write" "Read" "Edit" "MultiEdit" "Glob" "Grep"
    "Task" "TodoWrite" "WebFetch" "WebSearch" "Bash"
    "Bash(git *)" "Bash(npm *)" "Bash(bats *)"
    "Bash(python *)" "Bash(node *)" "NotebookEdit"
)

mkdir -p "$LOG_DIR" "$DOCS_DIR" "docs/plans"

# Source shared logging library
source "$SCRIPT_DIR/lib/logging.sh"

# A1: file integrity validation (upstream lib/file_protection.sh).
source "$SCRIPT_DIR/lib/file_protection.sh"

# A6: per-iteration log rotation (upstream lib/log_utils.sh, adapted).
source "$SCRIPT_DIR/lib/log_utils.sh"

# =============================================================================
# NOTIFICATIONS (A8)
# =============================================================================
# Cross-platform desktop notification helper. macOS (osascript), Linux
# (notify-send), fallback to terminal bell. No-op when ENABLE_NOTIFICATIONS
# is not "true". Any failure is swallowed so notification problems never
# kill the loop.
send_notification() {
    local title="$1"
    local message="$2"

    [[ "${ENABLE_NOTIFICATIONS:-false}" == "true" ]] || return 0

    # Strip double quotes so we can't break an AppleScript string literal.
    local safe_title="${title//\"/}"
    local safe_message="${message//\"/}"

    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$safe_message\" with title \"$safe_title\"" 2>/dev/null || true
    elif command -v notify-send &>/dev/null; then
        notify-send "$title" "$message" 2>/dev/null || true
    else
        printf '\a\n' 2>/dev/null || true
    fi
}

# =============================================================================
# RALPHRC CONFIGURATION
# =============================================================================

RALPHRC_LOADED=false

load_ralphrc() {
    if [[ ! -f "$RALPHRC_FILE" ]]; then
        return 0
    fi

    # shellcheck source=/dev/null
    source "$RALPHRC_FILE"

    # Map .ralphrc variable names to internal names
    [[ -n "${ALLOWED_TOOLS:-}" ]] && CLAUDE_ALLOWED_TOOLS="$ALLOWED_TOOLS"
    [[ -n "${SESSION_CONTINUITY:-}" ]] && CLAUDE_USE_CONTINUE="$SESSION_CONTINUITY"
    [[ -n "${SESSION_EXPIRY_HOURS:-}" ]] && CLAUDE_SESSION_EXPIRY_HOURS="$SESSION_EXPIRY_HOURS"
    [[ -n "${RALPH_VERBOSE:-}" ]] && VERBOSE_PROGRESS="$RALPH_VERBOSE"

    # A3: respect .ralphrc overrides for new vars too (and then re-apply env
    # snapshots so env > ralphrc > defaults precedence holds).
    [[ -n "${CLAUDE_CODE_CMD:-}" ]] && : # already set via env-or-default above
    [[ -n "${CLAUDE_MODEL:-}" ]] && :
    [[ -n "${CLAUDE_EFFORT:-}" ]] && :

    # Restore values explicitly set via environment variables (env > ralphrc > defaults)
    [[ -n "$_env_MAX_CALLS_PER_HOUR" ]] && MAX_CALLS_PER_HOUR="$_env_MAX_CALLS_PER_HOUR"
    [[ -n "$_env_CLAUDE_TIMEOUT_MINUTES" ]] && CLAUDE_TIMEOUT_MINUTES="$_env_CLAUDE_TIMEOUT_MINUTES"
    [[ -n "$_env_CLAUDE_OUTPUT_FORMAT" ]] && CLAUDE_OUTPUT_FORMAT="$_env_CLAUDE_OUTPUT_FORMAT"
    [[ -n "$_env_CLAUDE_ALLOWED_TOOLS" ]] && CLAUDE_ALLOWED_TOOLS="$_env_CLAUDE_ALLOWED_TOOLS"
    [[ -n "$_env_CLAUDE_USE_CONTINUE" ]] && CLAUDE_USE_CONTINUE="$_env_CLAUDE_USE_CONTINUE"
    [[ -n "$_env_CLAUDE_SESSION_EXPIRY_HOURS" ]] && CLAUDE_SESSION_EXPIRY_HOURS="$_env_CLAUDE_SESSION_EXPIRY_HOURS"
    [[ -n "$_env_VERBOSE_PROGRESS" ]] && VERBOSE_PROGRESS="$_env_VERBOSE_PROGRESS"
    [[ -n "$_env_MAX_CONSECUTIVE_TEST_LOOPS" ]] && MAX_CONSECUTIVE_TEST_LOOPS="$_env_MAX_CONSECUTIVE_TEST_LOOPS"
    [[ -n "$_env_MAX_CONSECUTIVE_DONE_SIGNALS" ]] && MAX_CONSECUTIVE_DONE_SIGNALS="$_env_MAX_CONSECUTIVE_DONE_SIGNALS"
    [[ -n "$_env_CLAUDE_CODE_CMD" ]] && CLAUDE_CODE_CMD="$_env_CLAUDE_CODE_CMD"
    [[ -n "$_env_CLAUDE_MODEL" ]] && CLAUDE_MODEL="$_env_CLAUDE_MODEL"
    [[ -n "$_env_CLAUDE_EFFORT" ]] && CLAUDE_EFFORT="$_env_CLAUDE_EFFORT"
    [[ -n "$_env_ENABLE_NOTIFICATIONS" ]] && ENABLE_NOTIFICATIONS="$_env_ENABLE_NOTIFICATIONS"
    [[ -n "$_env_MAX_TOKENS_PER_HOUR" ]] && MAX_TOKENS_PER_HOUR="$_env_MAX_TOKENS_PER_HOUR"
    [[ -n "$_env_RALPH_SHELL_INIT_FILE" ]] && RALPH_SHELL_INIT_FILE="$_env_RALPH_SHELL_INIT_FILE"
    [[ -n "$_env_SUPER_RALPH_SHELL_INIT_FILE" ]] && SUPER_RALPH_SHELL_INIT_FILE="$_env_SUPER_RALPH_SHELL_INIT_FILE"
    [[ -n "$_env_ENABLE_BACKUP" ]] && ENABLE_BACKUP="$_env_ENABLE_BACKUP"

    # A9: CLI --backup / -b must outrank .ralphrc ENABLE_BACKUP=false.
    [[ "${_cli_ENABLE_BACKUP:-false}" == "true" ]] && ENABLE_BACKUP=true

    RALPHRC_LOADED=true
    return 0
}

# =============================================================================
# TOOL VALIDATION
# =============================================================================

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

# =============================================================================
# PROJECT TYPE AUTO-DETECTION
# =============================================================================

detect_project_tools() {
    local base_tools="Write,Read,Edit,Bash(git *)"
    local detected_tools=""

    # Node.js / JavaScript / TypeScript
    if [[ -f "package.json" ]]; then
        detected_tools+=",Bash(npm *),Bash(npx *),Bash(node *)"
        if [[ -f "yarn.lock" ]]; then
            detected_tools+=",Bash(yarn *)"
        fi
        if [[ -f "pnpm-lock.yaml" ]]; then
            detected_tools+=",Bash(pnpm *)"
        fi
        if [[ -f "bun.lockb" ]] || [[ -f "bunfig.toml" ]]; then
            detected_tools+=",Bash(bun *)"
        fi
    fi

    # Python
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "setup.cfg" ]] || [[ -f "Pipfile" ]] || [[ -f "requirements.txt" ]]; then
        detected_tools+=",Bash(python *),Bash(python3 *),Bash(pip *),Bash(pytest *)"
        if [[ -f "Pipfile" ]]; then
            detected_tools+=",Bash(pipenv *)"
        fi
        if [[ -f "poetry.lock" ]] || grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
            detected_tools+=",Bash(poetry *)"
        fi
        if [[ -f "uv.lock" ]]; then
            detected_tools+=",Bash(uv *)"
        fi
    fi

    # Rust
    if [[ -f "Cargo.toml" ]]; then
        detected_tools+=",Bash(cargo *),Bash(rustc *)"
    fi

    # Go
    if [[ -f "go.mod" ]]; then
        detected_tools+=",Bash(go *)"
    fi

    # Java / Kotlin
    if [[ -f "pom.xml" ]]; then
        detected_tools+=",Bash(mvn *),Bash(java *)"
    fi
    if [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; then
        detected_tools+=",Bash(gradle *),Bash(./gradlew *),Bash(java *)"
    fi

    # Ruby
    if [[ -f "Gemfile" ]]; then
        detected_tools+=",Bash(ruby *),Bash(bundle *),Bash(rake *),Bash(rspec *)"
    fi

    # Elixir
    if [[ -f "mix.exs" ]]; then
        detected_tools+=",Bash(mix *),Bash(elixir *),Bash(iex *)"
    fi

    # PHP
    if [[ -f "composer.json" ]]; then
        detected_tools+=",Bash(php *),Bash(composer *),Bash(phpunit *)"
    fi

    # .NET / C#
    if ls ./*.csproj &>/dev/null || ls ./*.sln &>/dev/null || [[ -f "global.json" ]]; then
        detected_tools+=",Bash(dotnet *)"
    fi

    # Swift
    if [[ -f "Package.swift" ]]; then
        detected_tools+=",Bash(swift *),Bash(swiftc *)"
    fi

    # Zig
    if [[ -f "build.zig" ]]; then
        detected_tools+=",Bash(zig *)"
    fi

    # Scala
    if [[ -f "build.sbt" ]]; then
        detected_tools+=",Bash(sbt *),Bash(scala *)"
    fi

    # Shell / Bash testing
    detected_tools+=",Bash(bats *)"

    # Docker
    if [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        detected_tools+=",Bash(docker *),Bash(docker-compose *)"
    fi

    # Make
    if [[ -f "Makefile" ]]; then
        detected_tools+=",Bash(make *)"
    fi

    echo "${base_tools}${detected_tools}"
}

# Apply auto-detection if no explicit tools were set
if [[ "$CLAUDE_ALLOWED_TOOLS" == "__AUTO_DETECT__" ]]; then
    CLAUDE_ALLOWED_TOOLS=$(detect_project_tools)
fi

# =============================================================================
# SUPERPOWERS METHODOLOGY LAYER
# =============================================================================

build_superpowers_context() {
    local loop_count=$1
    local task_text="$2"
    local task_type="$3"
    local skills="$4"
    local remaining
    remaining=$(count_remaining_tasks)

    local context="[Super-Ralph Loop #${loop_count}] "
    context+="Remaining tasks: ${remaining}. "

    if [[ -n "$task_type" ]]; then
        context+="Current task type: ${task_type}. "
        context+="Required skills: $(echo "$skills" | tr ':' ', '). "
    fi

    context+="$(get_tdd_enforcement_context) "
    context+="$(get_verification_enforcement_context) "

    if [[ -f "$METHODOLOGY_FILE" ]]; then
        local prev_methodology
        prev_methodology=$(jq -r '.methodology // ""' "$METHODOLOGY_FILE" 2>/dev/null)
        if [[ -n "$prev_methodology" && "$prev_methodology" != "null" ]]; then
            context+="Previous methodology: ${prev_methodology}. "
        fi
    fi

    echo "${context:0:$MAX_LOOP_CONTEXT_LENGTH}"
}

record_methodology() {
    local methodology=$1
    local skill_used=$2
    local loop_number=$3

    jq -n \
        --arg methodology "$methodology" \
        --arg skill_used "$skill_used" \
        --argjson loop_number "$loop_number" \
        --arg timestamp "$(get_iso_timestamp)" \
        '{
            methodology: $methodology,
            skill_used: $skill_used,
            loop_number: $loop_number,
            timestamp: $timestamp
        }' > "$METHODOLOGY_FILE"
}

# =============================================================================
# RATE LIMITING & CALL TRACKING (standalone)
# =============================================================================

init_call_tracking() {
    local current_hour
    current_hour=$(date +%Y%m%d%H)
    local last_reset_hour=""

    if [[ -f "$TIMESTAMP_FILE" ]]; then
        last_reset_hour=$(cat "$TIMESTAMP_FILE")
    fi

    if [[ "$current_hour" != "$last_reset_hour" ]]; then
        echo "0" > "$CALL_COUNT_FILE"
        # A4: reset the token counter alongside the call counter at hour roll.
        echo "0" > "$TOKEN_COUNT_FILE"
        echo "$current_hour" > "$TIMESTAMP_FILE"
    fi

    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    fi

    if type init_circuit_breaker &>/dev/null 2>&1; then
        init_circuit_breaker
    fi
}

can_make_call() {
    local calls_made=0
    if [[ -f "$CALL_COUNT_FILE" ]]; then
        calls_made=$(cat "$CALL_COUNT_FILE")
    fi
    if [[ $calls_made -ge $MAX_CALLS_PER_HOUR ]]; then
        return 1
    fi

    # A4: optional token-budget enforcement (MAX_TOKENS_PER_HOUR > 0).
    if [[ "${MAX_TOKENS_PER_HOUR:-0}" -gt 0 ]] 2>/dev/null; then
        local tokens_used=0
        tokens_used=$(cat "$TOKEN_COUNT_FILE" 2>/dev/null || echo "0")
        if [[ $tokens_used -ge $MAX_TOKENS_PER_HOUR ]]; then
            return 1
        fi
    fi
    return 0
}

# A4: extract total token usage from a Claude output file. Supports both
# stream-json result frames (.usage.*) and CLI metadata (.metadata.usage.*).
extract_token_usage() {
    local output_file=$1
    if [[ ! -f "$output_file" ]]; then
        echo "0"
        return
    fi
    local tokens
    tokens=$(jq -r '
        ((.usage.input_tokens // .metadata.usage.input_tokens // 0) |
         if type == "number" then . else 0 end) +
        ((.usage.output_tokens // .metadata.usage.output_tokens // 0) |
         if type == "number" then . else 0 end)
    ' "$output_file" 2>/dev/null)
    echo "${tokens:-0}"
}

# A4: accumulate token usage after each Claude invocation.
update_token_count() {
    local output_file=$1
    local new_tokens
    new_tokens=$(extract_token_usage "$output_file")
    if [[ "$new_tokens" -gt 0 ]] 2>/dev/null; then
        local current=0
        current=$(cat "$TOKEN_COUNT_FILE" 2>/dev/null || echo "0")
        local total=$((current + new_tokens))
        echo "$total" > "$TOKEN_COUNT_FILE"
        if [[ "${MAX_TOKENS_PER_HOUR:-0}" -gt 0 ]] 2>/dev/null; then
            log_status "INFO" "Tokens this hour: $total/$MAX_TOKENS_PER_HOUR (+${new_tokens})"
        else
            log_status "INFO" "Tokens this hour: $total (+${new_tokens})"
        fi
    fi
}

increment_call_counter() {
    local calls_made=0
    local lock_file="${CALL_COUNT_FILE}.lock"

    # Use flock if available for atomic read-increment-write
    if command -v flock &>/dev/null; then
        # Intentional: outer variable is spliced into inner single-quoted script
        # shellcheck disable=SC2016
        calls_made=$(
            flock -w 5 "$lock_file" bash -c '
                count=0
                [[ -f "'"$CALL_COUNT_FILE"'" ]] && count=$(cat "'"$CALL_COUNT_FILE"'")
                count=$((count + 1))
                echo "$count" > "'"$CALL_COUNT_FILE"'"
                echo "$count"
            '
        )
    else
        # Fallback without locking (macOS doesn't ship flock by default)
        if [[ -f "$CALL_COUNT_FILE" ]]; then
            calls_made=$(cat "$CALL_COUNT_FILE")
        fi
        ((calls_made++))
        echo "$calls_made" > "$CALL_COUNT_FILE"
    fi

    echo "$calls_made"
}

wait_for_reset() {
    local calls_made
    calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    local tokens_used
    tokens_used=$(cat "$TOKEN_COUNT_FILE" 2>/dev/null || echo "0")
    local limit_reason="calls: $calls_made/$MAX_CALLS_PER_HOUR"
    if [[ "${MAX_TOKENS_PER_HOUR:-0}" -gt 0 ]] 2>/dev/null; then
        limit_reason="$limit_reason, tokens: $tokens_used/$MAX_TOKENS_PER_HOUR"
    fi
    log_status "WARN" "Rate limit reached ($limit_reason). Waiting for reset..."
    send_notification "Super-Ralph - Rate Limit" "Rate limit reached ($limit_reason). Waiting for reset..."

    local current_minute
    current_minute=$(date +%M)
    local current_second
    current_second=$(date +%S)
    # Use 10# prefix to force decimal interpretation (prevents octal issues with 08, 09)
    local wait_time=$(((60 - 10#$current_minute - 1) * 60 + (60 - 10#$current_second)))

    while [[ $wait_time -gt 0 ]]; do
        local minutes=$(((wait_time % 3600) / 60))
        local seconds=$((wait_time % 60))
        printf "\r${YELLOW}Time until reset: %02d:%02d${NC}" $minutes $seconds
        sleep 1
        ((wait_time--))
    done
    printf "\n"

    echo "0" > "$CALL_COUNT_FILE"
    echo "0" > "$TOKEN_COUNT_FILE"
    date +%Y%m%d%H > "$TIMESTAMP_FILE"
    log_status "SUCCESS" "Rate limit reset. Ready for new calls."
}

update_status() {
    local loop_count=$1
    local calls_made=$2
    local last_action=$3
    local status=$4
    local exit_reason=${5:-""}

    # A4: include token counters in the status snapshot.
    local tokens_used
    tokens_used=$(cat "$TOKEN_COUNT_FILE" 2>/dev/null || echo "0")

    cat > "$STATUS_FILE" << STATUSEOF
{
    "timestamp": "$(get_iso_timestamp)",
    "loop_count": $loop_count,
    "calls_made_this_hour": $calls_made,
    "max_calls_per_hour": $MAX_CALLS_PER_HOUR,
    "tokens_used_this_hour": $tokens_used,
    "max_tokens_per_hour": $MAX_TOKENS_PER_HOUR,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason",
    "next_reset": "$(get_next_hour_time)",
    "mode": "super-ralph"
}
STATUSEOF
}

# =============================================================================
# METRICS (A7)
# =============================================================================

# Append a JSON Lines metrics record to logs/metrics.jsonl.
# Arguments: loop_num duration_seconds success(true|false) calls_this_loop
track_metrics() {
    local loop_num=$1
    local duration=$2
    local success=$3
    local calls=$4

    local metrics_file="$LOG_DIR/metrics.jsonl"
    mkdir -p "$LOG_DIR"

    local ts
    ts=$(get_iso_timestamp)

    printf '{"timestamp":"%s","loop":%d,"duration":%d,"success":%s,"calls":%d}\n' \
        "$ts" "$loop_num" "$duration" "$success" "$calls" >> "$metrics_file"
}

# Log a one-line metrics summary on graceful exit.
print_metrics_summary() {
    local metrics_file="$LOG_DIR/metrics.jsonl"
    [[ -f "$metrics_file" ]] || return 0
    command -v jq &>/dev/null || return 0

    local summary
    summary=$(jq -s '{
        total_loops: length,
        successful: (map(select(.success==true)) | length),
        avg_duration: (if length > 0 then (map(.duration) | add) / length else 0 end),
        total_calls: (map(.calls) | add // 0)
    }' "$metrics_file" 2>/dev/null)
    [[ -n "$summary" ]] && log_status "INFO" "Metrics summary: $summary"
}

# =============================================================================
# CLAUDE CLI VALIDATION (A2)
# =============================================================================

# Verify that CLAUDE_CODE_CMD resolves to an executable before the loop
# tries to run. Returns 0 on success, 1 when the command is missing —
# callers should exit with a helpful message in the failure case.
validate_claude_command() {
    local cmd="$CLAUDE_CODE_CMD"

    if [[ "$cmd" == npx\ * ]] || [[ "$cmd" == "npx" ]]; then
        if ! command -v npx &>/dev/null; then
            echo ""
            echo -e "${RED}NPX NOT FOUND${NC}"
            echo ""
            echo -e "${YELLOW}CLAUDE_CODE_CMD is set to use npx, but npx is not installed.${NC}"
            echo "  1. Install Node.js (ships with npx): https://nodejs.org"
            echo "  2. Or install Claude Code globally:"
            echo "       npm install -g @anthropic-ai/claude-code"
            echo "       And set in .ralphrc: CLAUDE_CODE_CMD=\"claude\""
            echo ""
            return 1
        fi
        return 0
    fi

    # Non-npx command; check the first whitespace-separated token so callers
    # can set CLAUDE_CODE_CMD to something like "/opt/claude/claude --foo".
    local cmd_bin="${cmd%% *}"
    if ! command -v "$cmd_bin" &>/dev/null; then
        echo ""
        echo -e "${RED}CLAUDE CODE CLI NOT FOUND${NC}"
        echo ""
        echo -e "${YELLOW}The Claude Code CLI command '${cmd}' is not available.${NC}"
        echo "  1. Install globally (recommended):"
        echo "       npm install -g @anthropic-ai/claude-code"
        echo "  2. Or use npx: set CLAUDE_CODE_CMD=\"npx @anthropic-ai/claude-code\" in .ralphrc"
        echo ""
        return 1
    fi
    return 0
}

# =============================================================================
# BACKUP / ROLLBACK (A9)
# =============================================================================

# Create a git backup branch before a loop iteration. No-op when
# ENABLE_BACKUP != "true" or when the working dir isn't a git repo. Uses
# the "super-ralph-backup-loop-*" prefix to avoid colliding with Ralph's
# own "ralph-backup-loop-*" branches on machines running both.
create_backup() {
    local loop_count="${1:-0}"

    [[ "$ENABLE_BACKUP" == "true" ]] || return 0

    if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
        log_status "WARN" "Backup skipped: not a git repository"
        return 0
    fi

    local ts
    ts=$(date +%s)
    local branch_name="super-ralph-backup-loop-${loop_count}-${ts}"
    local msg="Super-Ralph backup before loop #${loop_count}"

    # Stash any local changes so checkout doesn't eat them.
    local stashed=false
    if ! git stash push -u -m "$msg" 2>/dev/null; then
        log_status "WARN" "Backup failed: could not stash local changes for loop #${loop_count}"
        return 0
    fi
    stashed=true

    if ! git checkout -b "$branch_name" -q 2>/dev/null; then
        log_status "WARN" "Backup failed: could not create branch $branch_name"
        git stash pop 2>/dev/null || true
        return 0
    fi

    if ! git add -A 2>/dev/null; then
        log_status "WARN" "Backup failed: could not stage files for loop #${loop_count}"
        git checkout - -q 2>/dev/null || true
        git stash pop 2>/dev/null || true
        return 0
    fi

    if ! git commit --allow-empty -q -m "$msg" 2>/dev/null; then
        log_status "WARN" "Backup failed: commit failed for loop #${loop_count}"
        git checkout - -q 2>/dev/null || true
        git stash pop 2>/dev/null || true
        return 0
    fi

    if ! git checkout - -q 2>/dev/null; then
        log_status "WARN" "Backup: could not switch back from $branch_name — manual cleanup may be needed"
    fi

    if [[ "$stashed" == "true" ]]; then
        git stash pop 2>/dev/null || log_status "WARN" "Backup: stash pop failed — run 'git stash pop' to restore your changes"
    fi

    log_status "INFO" "Backup created: $branch_name"
    return 0
}

# Roll back to a previously created backup branch. With no argument the
# function lists available backups newest-first. With a branch name it
# checks that branch out directly.
rollback_to_backup() {
    local branch="${1:-}"

    if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
        log_status "ERROR" "Rollback failed: not a git repository"
        return 1
    fi

    if [[ -z "$branch" ]]; then
        local backups
        # Sort by the unix-timestamp field (5th '-'-delimited token).
        backups=$(git branch --list "super-ralph-backup-loop-*" 2>/dev/null \
            | sed 's/^[* ]*//' \
            | sort -t- -k6,6 -rn)
        if [[ -z "$backups" ]]; then
            log_status "WARN" "No Super-Ralph backup branches found"
            return 1
        fi
        echo "Available backups (newest first):"
        echo "$backups"
        return 0
    fi

    if ! git rev-parse --verify "$branch" &>/dev/null 2>&1; then
        log_status "ERROR" "Rollback failed: branch '$branch' not found"
        return 1
    fi

    if ! git checkout "$branch" -q 2>/dev/null; then
        log_status "ERROR" "Rollback failed: could not checkout $branch"
        return 1
    fi

    log_status "INFO" "Rolled back to: $branch"
    return 0
}

# =============================================================================
# GIT DIFF HELPERS
# =============================================================================

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

# =============================================================================
# SESSION MANAGEMENT (extracted to lib/session_manager.sh)
# =============================================================================

source "$SCRIPT_DIR/lib/session_manager.sh"

# =============================================================================
# BUILD CLAUDE COMMAND
# =============================================================================

build_claude_command() {
    local prompt_file=$1
    local loop_context=$2
    local session_id=$3

    CLAUDE_CMD_ARGS=("$CLAUDE_CODE_CMD")

    if [[ ! -f "$prompt_file" ]]; then
        log_status "ERROR" "Prompt file not found: $prompt_file"
        return 1
    fi

    # A3: model / effort overrides (upstream b31640a). Empty string = CLI default.
    if [[ -n "${CLAUDE_MODEL:-}" ]]; then
        CLAUDE_CMD_ARGS+=("--model" "$CLAUDE_MODEL")
    fi
    if [[ -n "${CLAUDE_EFFORT:-}" ]]; then
        CLAUDE_CMD_ARGS+=("--effort" "$CLAUDE_EFFORT")
    fi

    if [[ "$CLAUDE_OUTPUT_FORMAT" == "json" ]]; then
        CLAUDE_CMD_ARGS+=("--output-format" "json")
    fi

    if [[ -n "$CLAUDE_ALLOWED_TOOLS" ]]; then
        CLAUDE_CMD_ARGS+=("--allowedTools")
        local IFS=','
        read -ra tools_array <<< "$CLAUDE_ALLOWED_TOOLS"
        for tool in "${tools_array[@]}"; do
            tool=$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$tool" ]] && CLAUDE_CMD_ARGS+=("$tool")
        done
    fi

    # Use --resume with explicit session ID (not --continue which can hijack sessions)
    if [[ "$CLAUDE_USE_CONTINUE" == "true" && -n "$session_id" ]]; then
        CLAUDE_CMD_ARGS+=("--resume" "$session_id")
    fi

    if [[ -n "$loop_context" ]]; then
        CLAUDE_CMD_ARGS+=("--append-system-prompt" "$loop_context")
    fi

    local prompt_content
    prompt_content=$(cat "$prompt_file")
    CLAUDE_CMD_ARGS+=("-p" "$prompt_content")
}

# =============================================================================
# BUILD LOOP CONTEXT (Ralph base + superpowers methodology)
# =============================================================================

build_loop_context() {
    local loop_count=$1
    local context=""

    # --- Ralph base context ---
    context="Loop #${loop_count}. "

    if [[ -f "$SUPER_RALPH_DIR/fix_plan.md" ]]; then
        local incomplete_tasks
        incomplete_tasks=$(grep -cE "^[[:space:]]*- \[ \]" "$SUPER_RALPH_DIR/fix_plan.md" 2>/dev/null || true)
        [[ -z "$incomplete_tasks" ]] && incomplete_tasks=0
        context+="Remaining tasks: ${incomplete_tasks}. "
    fi

    if [[ -f "$SUPER_RALPH_DIR/.circuit_breaker_state" ]]; then
        local cb_state
        cb_state=$(jq -r '.state // "UNKNOWN"' "$SUPER_RALPH_DIR/.circuit_breaker_state" 2>/dev/null)
        if [[ "$cb_state" != "CLOSED" && "$cb_state" != "null" && -n "$cb_state" ]]; then
            context+="Circuit breaker: ${cb_state}. "
        fi
    fi

    if [[ -f "$RESPONSE_ANALYSIS_FILE" ]]; then
        local prev_summary
        prev_summary=$(jq -r '.analysis.work_summary // ""' "$RESPONSE_ANALYSIS_FILE" 2>/dev/null | head -c 200)
        if [[ -n "$prev_summary" && "$prev_summary" != "null" ]]; then
            context+="Previous: ${prev_summary} "
        fi
    fi

    # --- Superpowers methodology context ---
    local task_text
    task_text=$(get_current_task)
    local task_type=""
    local skills=""

    if [[ -n "$task_text" ]]; then
        task_type=$(classify_task "$task_text")
        skills=$(get_skill_workflow "$task_type")
        context+="Task type: ${task_type}. Skills: $(echo "$skills" | tr ':' ', '). "
        log_status "SKILL" "Task: '$task_text' -> Type: $task_type | Skills: $(echo "$skills" | tr ':' ' -> ')"
    elif all_tasks_complete 2>/dev/null; then
        task_type="COMPLETION"
        skills="verification-before-completion:finishing-a-development-branch"
        context+="All tasks complete - entering verification phase. "
        log_status "SKILL" "All tasks complete - entering verification phase"
    fi

    # Record methodology for tracking
    if [[ -n "$task_type" ]]; then
        local methodology="TDD"
        case "$task_type" in
            "FEATURE") methodology="BRAINSTORMING" ;;
            "BUG") methodology="DEBUGGING" ;;
            "COMPLETION") methodology="VERIFICATION" ;;
            "REVIEW") methodology="REVIEW" ;;
        esac
        record_methodology "$methodology" "$(echo "$skills" | cut -d: -f1)" "$loop_count"
    fi

    context+="$(get_tdd_enforcement_context) "
    context+="$(get_verification_enforcement_context) "

    if [[ -f "$METHODOLOGY_FILE" ]]; then
        local prev_methodology
        prev_methodology=$(jq -r '.methodology // ""' "$METHODOLOGY_FILE" 2>/dev/null)
        if [[ -n "$prev_methodology" && "$prev_methodology" != "null" ]]; then
            context+="Previous methodology: ${prev_methodology}. "
        fi
    fi

    # Limit total length
    echo "${context:0:$MAX_LOOP_CONTEXT_LENGTH}"
}

# =============================================================================
# SUPERPOWERS-ENHANCED EXECUTION
# =============================================================================

execute_super_ralph() {
    local loop_count=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"
    # P15: capture claude CLI stderr in a sibling file so Node/undici warnings
    # don't corrupt the stdout JSON stream that jq parses in live mode.
    local stderr_file="$LOG_DIR/claude_stderr_${timestamp}.log"

    # A5: dry-run short-circuits before any API work or counter bump.
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_status "INFO" "[DRY RUN] Skipping Claude Code execution for loop $loop_count"
        log_status "INFO" "[DRY RUN] Would execute $CLAUDE_CODE_CMD with prompt: $PROMPT_FILE"
        log_status "INFO" "[DRY RUN] Output format: $CLAUDE_OUTPUT_FORMAT, timeout: ${CLAUDE_TIMEOUT_MINUTES}m"
        sleep 2
        log_status "INFO" "[DRY RUN] Simulation complete — no API call made"
        return 0
    fi

    # Capture git HEAD SHA for progress detection
    local loop_start_sha=""
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
        loop_start_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    fi
    echo "$loop_start_sha" > "$SUPER_RALPH_DIR/.loop_start_sha"

    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))

    # P17: build loop context unconditionally (was gated on CLAUDE_USE_CONTINUE).
    # Fresh sessions without continuity need loop count / previous summary /
    # circuit-breaker state just as much, if not more, than continued ones.
    local loop_context=""
    loop_context=$(build_loop_context "$loop_count")
    if [[ -n "$loop_context" && "$VERBOSE_PROGRESS" == "true" ]]; then
        log_status "INFO" "Loop context: $loop_context"
    fi

    # Initialize or resume session
    local session_id=""
    if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
        session_id=$(init_claude_session)
    fi

    # Build command array
    local use_modern_cli=false
    if [[ "$CLAUDE_OUTPUT_FORMAT" == "json" ]]; then
        if build_claude_command "$PROMPT_FILE" "$loop_context" "$session_id"; then
            use_modern_cli=true
            log_status "INFO" "Using modern CLI mode (JSON output)"
        else
            log_status "WARN" "Failed to build modern CLI command, falling back to legacy mode"
        fi
    else
        log_status "INFO" "Using legacy CLI mode (text output)"
    fi

    # P16: persist the API call counter immediately (not only on success) so
    # the monitor dashboard reflects attempts, including failures and timeouts.
    local calls_made
    calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    calls_made=$((calls_made + 1))
    echo "$calls_made" > "$CALL_COUNT_FILE"

    log_status "LOOP" "Executing Claude Code (Call $calls_made/$MAX_CALLS_PER_HOUR, timeout: ${CLAUDE_TIMEOUT_MINUTES}m)"

    # Initialize live.log for this execution
    echo -e "\n\n=== Loop #$loop_count - $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LIVE_LOG_FILE"

    local exit_code=0

    if [[ "$LIVE_OUTPUT" == "true" ]]; then
        # Live streaming mode (requires jq)
        # P12: stdbuf removed — Homebrew coreutils stdbuf uses DYLD_INSERT_LIBRARIES
        # and is rejected by /usr/bin/tee on arm64e Apple Silicon, crashing --live.
        # claude flushes per-event, tee is write-through, and jq --unbuffered
        # self-flushes, so stdbuf adds nothing.
        if ! command -v jq &>/dev/null; then
            log_status "ERROR" "Live mode requires 'jq'. Falling back to background mode."
            LIVE_OUTPUT=false
        fi
    fi

    if [[ "$LIVE_OUTPUT" == "true" && "$use_modern_cli" == "true" ]]; then
        log_status "INFO" "Live output mode enabled - showing Claude Code streaming..."
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━ Claude Code Output ━━━━━━━━━━━━━━━━${NC}"

        # Replace json with stream-json for live output
        local -a LIVE_CMD_ARGS=()
        local skip_next=false
        for arg in "${CLAUDE_CMD_ARGS[@]}"; do
            if [[ "$skip_next" == "true" ]]; then
                LIVE_CMD_ARGS+=("stream-json")
                skip_next=false
            elif [[ "$arg" == "--output-format" ]]; then
                LIVE_CMD_ARGS+=("$arg")
                skip_next=true
            else
                LIVE_CMD_ARGS+=("$arg")
            fi
        done
        LIVE_CMD_ARGS+=("--verbose" "--include-partial-messages")

        local jq_filter='
            if .type == "stream_event" then
                if .event.type == "content_block_delta" and .event.delta.type == "text_delta" then
                    .event.delta.text
                elif .event.type == "content_block_start" and .event.content_block.type == "tool_use" then
                    "\n\n[" + .event.content_block.name + "]\n"
                elif .event.type == "content_block_stop" then
                    "\n"
                else
                    empty
                end
            elif .type == "system" and .subtype == "task_started" then
                "\n[agent: " + (.agent // "subagent") + " started" + (if .description then " — " + .description else "" end) + "]\n"
            elif .type == "system" and .subtype == "task_progress" then
                "\n[agent: " + (.agent // "subagent") + " progress" + (if .description then " — " + .description else "" end) + "]\n"
            else
                empty
            end'

        # P2: disable errexit across the pipeline — portable_timeout returns
        # 124 on a Claude hang, which under set -e+pipefail would silently kill
        # the whole loop. We restore set -e immediately after and handle the
        # exit code explicitly.
        # P12: removed stdbuf from all stages of the pipeline (see above).
        # P15: route claude's stderr to a separate file instead of merging it
        # into stdout via `2>&1`, so Node/undici warnings don't corrupt the
        # JSON stream fed to jq.
        set +e
        set -o pipefail
        portable_timeout ${timeout_seconds}s "${LIVE_CMD_ARGS[@]}" \
            2>"$stderr_file" | tee "$output_file" | jq --unbuffered -j "$jq_filter" 2>/dev/null | tee "$LIVE_LOG_FILE"

        local -a pipe_status=("${PIPESTATUS[@]}")
        set +o pipefail
        set -e
        exit_code=${pipe_status[0]}

        if [[ $exit_code -eq 124 ]]; then
            log_status "WARN" "Claude Code timed out after ${CLAUDE_TIMEOUT_MINUTES}m in live mode (exit 124)"
        fi

        [[ ${pipe_status[1]:-0} -ne 0 ]] && log_status "WARN" "Failed to write stream output to log file"
        [[ ${pipe_status[2]:-0} -ne 0 ]] && log_status "WARN" "jq filter had issues parsing some stream events"

        # P15: surface captured stderr so users can still see CLI warnings.
        if [[ -s "$stderr_file" ]]; then
            log_status "WARN" "Claude CLI stderr output detected (see $stderr_file)"
        else
            rm -f "$stderr_file" 2>/dev/null || true
        fi

        echo ""
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━ End of Output ━━━━━━━━━━━━━━━━━━━${NC}"

        # P14: always normalize the stream-json log to a single result JSON
        # object. Previously gated on CLAUDE_USE_CONTINUE=true, so continuity-off
        # runs left the raw stream frames in $output_file and downstream jq
        # consumers crashed under set -e.
        if [[ -f "$output_file" ]]; then
            local stream_output_file="${output_file%.log}_stream.log"
            cp "$output_file" "$stream_output_file"
            local result_line
            result_line=$(grep -E '"type"[[:space:]]*:[[:space:]]*"result"' "$output_file" 2>/dev/null | tail -1)
            if [[ -n "$result_line" ]]; then
                if echo "$result_line" | jq -e . >/dev/null 2>&1; then
                    echo "$result_line" > "$output_file"
                else
                    cp "$stream_output_file" "$output_file"
                fi
            fi
        fi
    else
        # Background mode with progress monitoring
        if [[ "$use_modern_cli" == "true" ]]; then
            portable_timeout ${timeout_seconds}s "${CLAUDE_CMD_ARGS[@]}" > "$output_file" 2>&1 &
        else
            portable_timeout ${timeout_seconds}s $CLAUDE_CODE_CMD < "$PROMPT_FILE" > "$output_file" 2>&1 &
        fi

        local claude_pid=$!
        local progress_counter=0

        # A2: early background-failure detection. If CLAUDE_CODE_CMD doesn't
        # exist or dies immediately, the backgrounded process exits before
        # the monitor loop runs; surface the failure with a helpful message
        # instead of hanging or silently returning.
        sleep 1
        if ! kill -0 "$claude_pid" 2>/dev/null; then
            wait "$claude_pid" 2>/dev/null
            local early_exit=$?
            log_status "ERROR" "Claude CLI process exited immediately (exit $early_exit)"
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                log_status "ERROR" "Last output: $(tail -5 "$output_file" 2>/dev/null | head -c 400)"
            fi
            return 1
        fi

        while kill -0 $claude_pid 2>/dev/null; do
            progress_counter=$((progress_counter + 1))

            local last_line=""
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                last_line=$(tail -1 "$output_file" 2>/dev/null | head -c 80)
                tail -c 50000 "$output_file" > "$LIVE_LOG_FILE" 2>/dev/null
            fi

            cat > "$PROGRESS_FILE" << EOF
{
    "status": "executing",
    "elapsed_seconds": $((progress_counter * 10)),
    "last_output": "$last_line",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

            if [[ "$VERBOSE_PROGRESS" == "true" ]]; then
                if [[ -n "$last_line" ]]; then
                    log_status "INFO" "Claude Code: $last_line... (${progress_counter}0s)"
                else
                    log_status "INFO" "Claude Code working... (${progress_counter}0s elapsed)"
                fi
            fi
            sleep "$PROGRESS_CHECK_INTERVAL"
        done

        wait $claude_pid
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        # P16: counter already persisted before execution; no duplicate write here.

        # P7: Claude CLI can exit 0 with `"is_error": true` on API 400 / token
        # expiry / tool-use-concurrency errors. Don't treat that as success —
        # reset the session, skip save, and fall through to failure reporting.
        local is_error="false"
        if [[ -f "$output_file" ]]; then
            is_error=$(jq -r '.is_error // false' "$output_file" 2>/dev/null)
            [[ "$is_error" == "null" ]] && is_error="false"
        fi
        if [[ "$is_error" == "true" ]]; then
            printf '{"status": "failed", "timestamp": "%s"}' "$(date '+%Y-%m-%d %H:%M:%S')" > "$PROGRESS_FILE"
            log_status "ERROR" "Claude Code returned is_error:true; resetting session"
            local err_msg
            err_msg=$(jq -r '.error // .result // ""' "$output_file" 2>/dev/null | head -c 200)
            if [[ -n "$err_msg" && "$err_msg" != "null" ]]; then
                log_status "ERROR" "Claude error: $err_msg"
            fi
            if echo "$err_msg" | grep -qi "tool.use.*concurrency\|concurrent tool"; then
                reset_session "tool_use_concurrency_error"
            else
                reset_session "api_error_is_error_true"
            fi
            return 1
        fi

        printf '{"status": "completed", "timestamp": "%s"}' "$(date '+%Y-%m-%d %H:%M:%S')" > "$PROGRESS_FILE"
        log_status "SUCCESS" "Claude Code execution completed"

        # Save session for continuity
        if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
            save_claude_session "$output_file"
        fi

        # A4: accumulate token usage for hourly limit tracking.
        update_token_count "$output_file"

        # Run superpowers post-execution checks
        log_status "SKILL" "Running TDD compliance check..."
        analyze_tdd_status "$output_file"
        log_tdd_summary

        log_status "SKILL" "Running verification gate..."
        analyze_verification_status "$output_file"
        log_verification_summary

        # Run Ralph's response analyzer if available
        if type analyze_response &>/dev/null 2>&1; then
            log_status "INFO" "Analyzing Claude Code response..."
            analyze_response "$output_file" "$loop_count"
            if type update_exit_signals &>/dev/null 2>&1; then
                update_exit_signals
            fi
            if type log_analysis_summary &>/dev/null 2>&1; then
                log_analysis_summary
            fi
        fi

        # Circuit breaker tracking
        if type record_loop_result &>/dev/null 2>&1; then
            local files_changed=0
            local loop_start_sha=""
            local current_sha=""

            if [[ -f "$SUPER_RALPH_DIR/.loop_start_sha" ]]; then
                loop_start_sha=$(cat "$SUPER_RALPH_DIR/.loop_start_sha" 2>/dev/null || echo "")
            fi

            if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
                current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
                files_changed=$(count_changed_files "$loop_start_sha" "$current_sha")
            fi

            local has_errors="false"
            if grep -v '"[^"]*error[^"]*":' "$output_file" 2>/dev/null | \
               grep -qE '(^Error:|^ERROR:|^error:|\]: error|Error occurred|failed with error|[Ee]xception|Fatal|FATAL)'; then
                has_errors="true"
            fi

            local output_length
            output_length=$(wc -c < "$output_file" 2>/dev/null || echo 0)

            record_loop_result "$loop_count" "$files_changed" "$has_errors" "$output_length"
            local circuit_result=$?

            if [[ $circuit_result -ne 0 ]]; then
                log_status "WARN" "Circuit breaker opened - halting execution"
                return 3
            fi
        fi

        return 0
    else
        printf '{"status": "failed", "timestamp": "%s"}' "$(date '+%Y-%m-%d %H:%M:%S')" > "$PROGRESS_FILE"

        # P4 Layer 1 (+ P9): timeout guard. Exit code 124 is a timeout, not an
        # API limit — don't false-trigger the 5-hour recovery flow. Before
        # treating the timeout as failure, check whether Claude made real
        # progress (productive timeout, #198).
        if [[ $exit_code -eq 124 ]]; then
            log_status "WARN" "Claude Code execution timed out (not an API limit)"

            local timeout_loop_start_sha=""
            local timeout_current_sha=""
            local timeout_files_changed=0

            if [[ -f "$SUPER_RALPH_DIR/.loop_start_sha" ]]; then
                timeout_loop_start_sha=$(cat "$SUPER_RALPH_DIR/.loop_start_sha" 2>/dev/null || echo "")
            fi

            if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
                timeout_current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
                timeout_files_changed=$(count_changed_files "$timeout_loop_start_sha" "$timeout_current_sha")
            fi

            if [[ $timeout_files_changed -gt 0 ]]; then
                log_status "INFO" "Timeout but $timeout_files_changed file(s) changed — treating iteration as productive"
                echo "{\"status\": \"timed_out_productive\", \"files_changed\": $timeout_files_changed, \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\"}" > "$PROGRESS_FILE"

                # Still save a session even though we timed out, so continuity
                # isn't broken for follow-up loops.
                if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
                    save_claude_session "$output_file"
                fi

                # Run the response analyzer pipeline on whatever output exists.
                if type analyze_response &>/dev/null 2>&1; then
                    log_status "INFO" "Analyzing response from productive timeout..."
                    analyze_response "$output_file" "$loop_count"
                    local timeout_analysis_exit=$?

                    if [[ $timeout_analysis_exit -eq 0 ]]; then
                        if type update_exit_signals &>/dev/null 2>&1; then
                            update_exit_signals
                        fi
                        if type log_analysis_summary &>/dev/null 2>&1; then
                            log_analysis_summary
                        fi
                    else
                        log_status "WARN" "Timeout response analysis failed (exit $timeout_analysis_exit); clearing stale analysis"
                        rm -f "$RESPONSE_ANALYSIS_FILE"
                    fi
                fi

                if type record_loop_result &>/dev/null 2>&1; then
                    local timeout_output_length
                    timeout_output_length=$(wc -c < "$output_file" 2>/dev/null || echo "0")
                    record_loop_result "$loop_count" "$timeout_files_changed" "false" "$timeout_output_length"
                    local timeout_circuit_result=$?
                    if [[ $timeout_circuit_result -ne 0 ]]; then
                        log_status "WARN" "Circuit breaker opened - halting execution"
                        return 3
                    fi
                fi

                return 0
            else
                log_status "WARN" "Timeout with no detectable progress"
                return 1
            fi
        fi

        # P4 Layer 2 (+ P5 whitespace tolerance): structural JSON check.
        # The definitive signal from the CLI is a rate_limit_event with
        # status:rejected; prefer it over text scanning.
        if grep -q '"rate_limit_event"' "$output_file" 2>/dev/null; then
            local last_rate_event
            last_rate_event=$(grep '"rate_limit_event"' "$output_file" 2>/dev/null | tail -1)
            if echo "$last_rate_event" | grep -qE '"status"[[:space:]]*:[[:space:]]*"rejected"'; then
                log_status "ERROR" "Claude API 5-hour usage limit reached"
                return 2
            fi
        fi

        # P4 Layer 3 (+ P5 whitespace tolerance): filtered text fallback.
        # Scan only the tail and skip tool-result / user-echo lines so
        # project files that happen to contain "5-hour limit" don't trigger
        # a false positive.
        if tail -30 "$output_file" 2>/dev/null \
            | grep -vE '"type"[[:space:]]*:[[:space:]]*"user"' \
            | grep -v '"tool_result"' \
            | grep -v '"tool_use_id"' \
            | grep -qi "5.*hour.*limit\|limit.*reached.*try.*back\|usage.*limit.*reached"; then
            log_status "ERROR" "Claude API 5-hour usage limit reached"
            return 2
        fi

        # P10 Layer 4: Extra Usage quota exhaustion (Ralph #100).
        # "You're out of extra usage · resets 9pm" uses a different message
        # than the 5-hour plan limit, but the user recovery flow is the same.
        if tail -30 "$output_file" 2>/dev/null \
            | grep -vE '"type"[[:space:]]*:[[:space:]]*"user"' \
            | grep -v '"tool_result"' \
            | grep -v '"tool_use_id"' \
            | grep -qi "out of extra usage"; then
            log_status "ERROR" "Claude Extra Usage quota exhausted"
            return 2
        fi

        log_status "ERROR" "Claude Code execution failed, check: $output_file"
        return 1
    fi
}

# =============================================================================
# GRACEFUL EXIT DETECTION & CONFIG VALIDATION (extracted to lib/exit_detector.sh)
# =============================================================================

source "$SCRIPT_DIR/lib/exit_detector.sh"

# =============================================================================
# TMUX MONITORING (extracted to lib/tmux_utils.sh)
# =============================================================================

source "$SCRIPT_DIR/lib/tmux_utils.sh"

# =============================================================================
# SIGNAL HANDLING
# =============================================================================

loop_count=0

cleanup() {
    log_status "INFO" "Super-Ralph loop interrupted. Cleaning up..."
    reset_session "manual_interrupt"
    update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "interrupted" "stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    if load_ralphrc; then
        if [[ "$RALPHRC_LOADED" == "true" ]]; then
            log_status "INFO" "Loaded configuration from .ralphrc"
            if ! validate_ralphrc; then
                log_status "ERROR" "Invalid configuration in .ralphrc"
                exit 1
            fi
        fi
    fi

    # A4: source an optional shell init file before running claude so
    # zsh-only users can export PATH / auth env vars via ~/.zshrc.
    # SUPER_RALPH_SHELL_INIT_FILE takes precedence over RALPH_SHELL_INIT_FILE.
    local shell_init_file="${SUPER_RALPH_SHELL_INIT_FILE:-${RALPH_SHELL_INIT_FILE:-}}"
    if [[ -n "$shell_init_file" ]]; then
        if [[ -f "$shell_init_file" ]]; then
            # shellcheck source=/dev/null
            source "$shell_init_file"
            log_status "INFO" "Sourced shell init file: $shell_init_file"
        else
            log_status "WARN" "Shell init file not found: $shell_init_file"
        fi
    fi

    # A2: pre-flight check that claude is actually invokable. Don't spin up a
    # loop that will hang on every iteration because the CLI is missing.
    if ! validate_claude_command; then
        log_status "ERROR" "Claude Code CLI not found: $CLAUDE_CODE_CMD"
        exit 1
    fi

    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Super-Ralph: Superpowers-Enhanced Development        ║"
    echo "║                                                              ║"
    echo "║  Brainstorm -> Plan -> TDD -> Review -> Verify               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ "$RALPH_INSTALLED" == "true" ]]; then
        log_status "INFO" "Mode: Ralph extension (Ralph infrastructure detected)"
    else
        log_status "INFO" "Mode: Standalone (using built-in infrastructure)"
    fi

    log_status "SUCCESS" "Super-Ralph loop starting"
    log_status "INFO" "Max calls/hour: $MAX_CALLS_PER_HOUR | Timeout: ${CLAUDE_TIMEOUT_MINUTES}m"

    # Check for old flat structure
    if [[ -f "PROMPT.md" ]] && [[ ! -d ".ralph" ]]; then
        log_status "ERROR" "This project uses the old flat structure."
        echo "Run 'ralph-migrate' or create .ralph/ directory."
        exit 1
    fi

    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_status "ERROR" "Prompt file '$PROMPT_FILE' not found!"
        echo ""
        echo "To fix:"
        echo "  1. Create new project: super-ralph-setup my-project"
        echo "  2. Or create .ralph/PROMPT.md manually"
        exit 1
    fi

    init_session_tracking
    init_call_tracking

    # A1: fail fast if any critical .ralph/ file is missing. Don't spin up a
    # loop that can't possibly make progress.
    if ! validate_ralph_integrity; then
        log_status "ERROR" "Super-Ralph project integrity check failed"
        get_integrity_report
        exit 1
    fi

    # P8: stale exit-signal state from a previous killed run can make a fresh
    # run graceful-exit on loop 1 before doing any work. Reset the signals
    # file and drop any leftover response-analysis snapshot.
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    rm -f "$RESPONSE_ANALYSIS_FILE"

    while true; do
        loop_count=$((loop_count + 1))
        # A6: rotate per-iteration Claude logs so .ralph/logs/ doesn't grow
        # unbounded in long-running projects.
        rotate_logs
        update_session_last_used

        log_status "LOOP" "=== Starting Loop #$loop_count ==="

        # Check circuit breaker
        if type should_halt_execution &>/dev/null 2>&1; then
            if should_halt_execution; then
                reset_session "circuit_breaker_open"
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted" "stagnation_detected"
                log_status "ERROR" "Circuit breaker has opened - execution halted"
                log_status "INFO" "Run 'super-ralph --reset-circuit' to reset after addressing issues"
                send_notification "Super-Ralph - Circuit Breaker" "Circuit breaker opened — execution halted due to stagnation"
                break
            fi
        fi

        # Check rate limits
        if ! can_make_call; then
            wait_for_reset
            continue
        fi

        # Check graceful exit
        local exit_reason
        exit_reason=$(should_exit_gracefully)
        if [[ -n "$exit_reason" ]]; then
            # Handle permission denied
            if [[ "$exit_reason" == "permission_denied" ]]; then
                log_status "ERROR" "Permission denied - halting loop"
                reset_session "permission_denied"
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "permission_denied" "halted" "permission_denied"
                echo ""
                echo -e "${RED}PERMISSION DENIED - Loop Halted${NC}"
                echo -e "${YELLOW}Update ALLOWED_TOOLS in .ralphrc to include the required tools.${NC}"
                echo ""
                break
            fi

            log_status "SUCCESS" "Graceful exit: $exit_reason"
            send_notification "Super-Ralph - Complete" "Project completed. Exit reason: $exit_reason"
            reset_session "project_complete"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "graceful_exit" "completed" "$exit_reason"

            log_status "SUCCESS" "Super-Ralph completed! Final stats:"
            log_status "INFO" "  - Total loops: $loop_count"
            log_status "INFO" "  - API calls: $(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")"
            log_status "INFO" "  - Exit reason: $exit_reason"
            # A7: aggregate metrics summary from .ralph/logs/metrics.jsonl.
            print_metrics_summary
            break
        fi

        # Execute with superpowers methodology
        local calls_made
        calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
        update_status "$loop_count" "$calls_made" "executing" "running"

        # A7: capture loop start timestamp and pre-execution call count so
        # the metrics record reflects per-iteration duration and call delta.
        local loop_start_epoch
        loop_start_epoch=$(get_epoch_seconds)
        local calls_before_exec="$calls_made"

        # A9: optional git backup branch before each iteration. Safe no-op
        # unless ENABLE_BACKUP=true and we're in a git repo.
        create_backup "$loop_count"

        execute_super_ralph "$loop_count"
        local exec_result=$?

        # A7: record per-loop metrics. Success flag mirrors exec_result == 0;
        # calls_this_loop is a delta so total_calls stays accurate across
        # hourly resets.
        local loop_duration
        loop_duration=$(( $(get_epoch_seconds) - loop_start_epoch ))
        local loop_success="false"
        [[ $exec_result -eq 0 ]] && loop_success="true"
        local calls_after_exec
        calls_after_exec=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
        local calls_this_loop=$(( calls_after_exec > calls_before_exec ? calls_after_exec - calls_before_exec : 0 ))
        track_metrics "$loop_count" "$loop_duration" "$loop_success" "$calls_this_loop"

        if [[ $exec_result -eq 0 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "completed" "success"
            sleep "$POST_EXECUTION_PAUSE"
        elif [[ $exec_result -eq 3 ]]; then
            reset_session "circuit_breaker_trip"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted" "stagnation_detected"
            log_status "ERROR" "Circuit breaker opened - halting"
            log_status "INFO" "Run 'super-ralph --reset-circuit' to reset"
            send_notification "Super-Ralph - Circuit Breaker" "Circuit breaker tripped — execution halted"
            break
        elif [[ $exec_result -eq 2 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "api_limit" "paused"
            log_status "WARN" "Claude API usage limit reached!"
            send_notification "Super-Ralph - API Limit" "Claude API usage limit reached (5-hour plan or Extra Usage)"
            # P10: copy covers both the 5-hour plan limit and Extra Usage quota.
            echo -e "\n${YELLOW}A Claude API usage limit has been reached (5-hour plan limit or Extra Usage quota).${NC}"
            echo -e "  ${GREEN}1)${NC} Wait for the limit to reset (usually within an hour)"
            echo -e "  ${GREEN}2)${NC} Exit the loop and try again later"
            echo -e "\n${BLUE}Choose an option (1 or 2):${NC} "

            # P3: read -t exits non-zero on timeout; `|| true` prevents set -e abort.
            read -r -t 30 -n 1 user_choice || true
            echo

            if [[ "$user_choice" == "2" ]] || [[ -z "$user_choice" ]]; then
                log_status "INFO" "User chose to exit (or timed out). Exiting loop..."
                # P8: reset the session so the next manual run doesn't inherit
                # this rate-limited one.
                reset_session "api_limit_exit"
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "api_limit_exit" "stopped" "api_5hour_limit"
                break
            else
                log_status "INFO" "User chose to wait. Waiting $((RATE_LIMIT_RETRY_SECONDS / 60)) minutes before retrying..."
                local wait_seconds=$RATE_LIMIT_RETRY_SECONDS
                while [[ $wait_seconds -gt 0 ]]; do
                    local minutes=$((wait_seconds / 60))
                    local seconds=$((wait_seconds % 60))
                    printf "\r${YELLOW}Time until retry: %02d:%02d${NC}" $minutes $seconds
                    sleep 1
                    ((wait_seconds--))
                done
                printf "\n"
            fi
        else
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "failed" "error"
            log_status "WARN" "Execution failed, waiting ${RETRY_BACKOFF_SECONDS} seconds before retry..."
            send_notification "Super-Ralph - Execution Failed" "Loop $loop_count failed — retrying in ${RETRY_BACKOFF_SECONDS}s"
            sleep "$RETRY_BACKOFF_SECONDS"
        fi

        log_status "LOOP" "=== Completed Loop #$loop_count ==="
    done
}

# =============================================================================
# CLI ARGUMENT PARSING
# =============================================================================

show_help() {
    cat << HELPEOF
Super-Ralph: Superpowers-Enhanced Autonomous Development

Usage: $0 [OPTIONS]

IMPORTANT: Run from a Super-Ralph project directory.
           Use 'super-ralph-setup project-name' to create a new project first.

Options:
    -h, --help              Show this help
    --version               Show version
    -c, --calls NUM         Max API calls per hour (default: $MAX_CALLS_PER_HOUR)
    -p, --prompt FILE       Prompt file (default: $PROMPT_FILE)
    -s, --status            Show current status
    -v, --verbose           Verbose progress output
    -l, --live              Show Claude Code output in real-time (streaming)
    -t, --timeout MIN       Execution timeout in minutes (default: $CLAUDE_TIMEOUT_MINUTES)
    -m, --monitor           Start with tmux session and live monitor
    --output-format FORMAT  json or text (default: $CLAUDE_OUTPUT_FORMAT)
    --allowed-tools TOOLS   Comma-separated tool list
    --no-continue           Disable session continuity
    --session-expiry HOURS  Session expiration time (default: $CLAUDE_SESSION_EXPIRY_HOURS)
    --reset-circuit         Reset circuit breaker
    --circuit-status        Show circuit breaker status
    --reset-session         Reset session state
    --dry-run               Simulate loop without making Claude API calls
    -n, --notify            Enable cross-platform desktop notifications
    --model MODEL           Override --model for Claude CLI (env: CLAUDE_MODEL)
    --effort LEVEL          Override --effort for Claude CLI (env: CLAUDE_EFFORT)
    -b, --backup            Create a git backup branch before each loop iteration
    --rollback [BRANCH]     Roll back to a super-ralph backup branch (lists if no arg)

Superpowers Features:
    - Automatic task classification (feature/bug/plan/completion/review)
    - TDD enforcement gate (test-first methodology)
    - Verification gate (evidence before completion claims)
    - Skill-based workflow selection (brainstorming, debugging, etc.)
    - Two-stage code review (spec compliance + quality)
    - Permission denial detection and recovery guidance

HELPEOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        --version) echo "super-ralph 1.2.1"; exit 0 ;;
        -c|--calls) MAX_CALLS_PER_HOUR="$2"; shift 2 ;;
        -p|--prompt) PROMPT_FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE_PROGRESS=true; shift ;;
        -l|--live) LIVE_OUTPUT=true; shift ;;
        -t|--timeout)
            if [[ "$2" =~ ^[1-9][0-9]*$ ]] && [[ "$2" -le 120 ]]; then
                CLAUDE_TIMEOUT_MINUTES="$2"
            else
                echo "Error: Timeout must be a positive integer between 1 and 120 minutes"
                exit 1
            fi
            shift 2
            ;;
        -m|--monitor) USE_TMUX=true; shift ;;
        --no-continue) CLAUDE_USE_CONTINUE=false; shift ;;
        --output-format)
            if [[ "$2" == "json" || "$2" == "text" ]]; then
                CLAUDE_OUTPUT_FORMAT="$2"
            else
                echo "Error: --output-format must be 'json' or 'text'"
                exit 1
            fi
            shift 2
            ;;
        --allowed-tools)
            if ! validate_allowed_tools "$2"; then
                exit 1
            fi
            CLAUDE_ALLOWED_TOOLS="$2"
            shift 2
            ;;
        --session-expiry)
            if [[ -z "$2" || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "Error: --session-expiry requires a positive integer (hours)"
                exit 1
            fi
            CLAUDE_SESSION_EXPIRY_HOURS="$2"
            shift 2
            ;;
        -s|--status)
            if [[ -f "$STATUS_FILE" ]]; then
                jq . "$STATUS_FILE" 2>/dev/null || cat "$STATUS_FILE"
                if [[ -f "$METHODOLOGY_FILE" ]]; then
                    echo ""
                    echo "Methodology State:"
                    jq . "$METHODOLOGY_FILE" 2>/dev/null || cat "$METHODOLOGY_FILE"
                fi
            else
                echo "No status file found."
            fi
            exit 0
            ;;
        --reset-circuit)
            if type reset_circuit_breaker &>/dev/null 2>&1; then
                reset_circuit_breaker "Manual reset via command line"
            fi
            reset_session "manual_circuit_reset"
            echo -e "${GREEN}Circuit breaker reset${NC}"
            exit 0
            ;;
        --circuit-status)
            if type show_circuit_status &>/dev/null 2>&1; then
                show_circuit_status
            else
                echo "Circuit breaker not available (Ralph not installed)"
            fi
            exit 0
            ;;
        --reset-session)
            reset_session "manual_reset_flag"
            echo -e "${GREEN}Session state reset successfully${NC}"
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -n|--notify)
            ENABLE_NOTIFICATIONS=true
            shift
            ;;
        --model)
            if [[ -z "$2" ]]; then
                echo "Error: --model requires a value"
                exit 1
            fi
            CLAUDE_MODEL="$2"
            shift 2
            ;;
        --effort)
            if [[ -z "$2" ]]; then
                echo "Error: --effort requires a value"
                exit 1
            fi
            CLAUDE_EFFORT="$2"
            shift 2
            ;;
        -b|--backup)
            ENABLE_BACKUP=true
            # _cli_ENABLE_BACKUP signals to load_ralphrc that --backup outranks
            # ENABLE_BACKUP=false in .ralphrc (A9 review feedback).
            _cli_ENABLE_BACKUP=true
            shift
            ;;
        --rollback)
            rollback_to_backup "${2:-}"
            exit $?
            ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$USE_TMUX" == "true" ]]; then
        check_tmux_available
        setup_tmux_session
    fi
    main
fi
