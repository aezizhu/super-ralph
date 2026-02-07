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
        date -v+1H '+%H:%M:%S' 2>/dev/null || date -d '+1 hour' '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S'
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
TIMESTAMP_FILE="$SUPER_RALPH_DIR/.last_reset"
EXIT_SIGNALS_FILE="$SUPER_RALPH_DIR/.exit_signals"
RESPONSE_ANALYSIS_FILE="$SUPER_RALPH_DIR/.response_analysis"
METHODOLOGY_FILE="$SUPER_RALPH_DIR/.methodology_state"
CLAUDE_SESSION_FILE="$SUPER_RALPH_DIR/.claude_session_id"
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

MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-100}"
CLAUDE_TIMEOUT_MINUTES="${CLAUDE_TIMEOUT_MINUTES:-15}"
CLAUDE_OUTPUT_FORMAT="${CLAUDE_OUTPUT_FORMAT:-json}"
CLAUDE_ALLOWED_TOOLS="${CLAUDE_ALLOWED_TOOLS:-Write,Read,Edit,Bash(git *),Bash(npm *),Bash(pytest),Bash(bats *)}"
CLAUDE_USE_CONTINUE="${CLAUDE_USE_CONTINUE:-true}"
CLAUDE_SESSION_EXPIRY_HOURS="${CLAUDE_SESSION_EXPIRY_HOURS:-24}"
CLAUDE_CODE_CMD="claude"
VERBOSE_PROGRESS="${VERBOSE_PROGRESS:-false}"
USE_TMUX=false
LIVE_OUTPUT=false

MAX_CONSECUTIVE_TEST_LOOPS=3
MAX_CONSECUTIVE_DONE_SIGNALS=2

VALID_TOOL_PATTERNS=(
    "Write" "Read" "Edit" "MultiEdit" "Glob" "Grep"
    "Task" "TodoWrite" "WebFetch" "WebSearch" "Bash"
    "Bash(git *)" "Bash(npm *)" "Bash(bats *)"
    "Bash(python *)" "Bash(node *)" "NotebookEdit"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$LOG_DIR" "$DOCS_DIR" "docs/plans"

# =============================================================================
# LOGGING
# =============================================================================

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
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/super-ralph.log"
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

    # Restore values explicitly set via environment variables (env > ralphrc > defaults)
    [[ -n "$_env_MAX_CALLS_PER_HOUR" ]] && MAX_CALLS_PER_HOUR="$_env_MAX_CALLS_PER_HOUR"
    [[ -n "$_env_CLAUDE_TIMEOUT_MINUTES" ]] && CLAUDE_TIMEOUT_MINUTES="$_env_CLAUDE_TIMEOUT_MINUTES"
    [[ -n "$_env_CLAUDE_OUTPUT_FORMAT" ]] && CLAUDE_OUTPUT_FORMAT="$_env_CLAUDE_OUTPUT_FORMAT"
    [[ -n "$_env_CLAUDE_ALLOWED_TOOLS" ]] && CLAUDE_ALLOWED_TOOLS="$_env_CLAUDE_ALLOWED_TOOLS"
    [[ -n "$_env_CLAUDE_USE_CONTINUE" ]] && CLAUDE_USE_CONTINUE="$_env_CLAUDE_USE_CONTINUE"
    [[ -n "$_env_CLAUDE_SESSION_EXPIRY_HOURS" ]] && CLAUDE_SESSION_EXPIRY_HOURS="$_env_CLAUDE_SESSION_EXPIRY_HOURS"
    [[ -n "$_env_VERBOSE_PROGRESS" ]] && VERBOSE_PROGRESS="$_env_VERBOSE_PROGRESS"

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

    echo "${context:0:800}"
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

wait_for_reset() {
    local calls_made
    calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    log_status "WARN" "Rate limit reached ($calls_made/$MAX_CALLS_PER_HOUR). Waiting for reset..."

    local current_minute
    current_minute=$(date +%M)
    local current_second
    current_second=$(date +%S)
    local wait_time=$(((60 - current_minute - 1) * 60 + (60 - current_second)))

    while [[ $wait_time -gt 0 ]]; do
        local minutes=$(((wait_time % 3600) / 60))
        local seconds=$((wait_time % 60))
        printf "\r${YELLOW}Time until reset: %02d:%02d${NC}" $minutes $seconds
        sleep 1
        ((wait_time--))
    done
    printf "\n"

    echo "0" > "$CALL_COUNT_FILE"
    echo "$(date +%Y%m%d%H)" > "$TIMESTAMP_FILE"
    log_status "SUCCESS" "Rate limit reset. Ready for new calls."
}

update_status() {
    local loop_count=$1
    local calls_made=$2
    local last_action=$3
    local status=$4
    local exit_reason=${5:-""}

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

# =============================================================================
# SESSION MANAGEMENT
# =============================================================================

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
    echo "${context:0:800}"
}

# =============================================================================
# SUPERPOWERS-ENHANCED EXECUTION
# =============================================================================

execute_super_ralph() {
    local loop_count=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"

    # Capture git HEAD SHA for progress detection
    local loop_start_sha=""
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
        loop_start_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    fi
    echo "$loop_start_sha" > "$SUPER_RALPH_DIR/.loop_start_sha"

    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))

    # Build loop context (Ralph base + superpowers methodology)
    local loop_context=""
    if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
        loop_context=$(build_loop_context "$loop_count")
        if [[ -n "$loop_context" && "$VERBOSE_PROGRESS" == "true" ]]; then
            log_status "INFO" "Loop context: $loop_context"
        fi
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

    local calls_made
    calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    calls_made=$((calls_made + 1))

    log_status "LOOP" "Executing Claude Code (Call $calls_made/$MAX_CALLS_PER_HOUR, timeout: ${CLAUDE_TIMEOUT_MINUTES}m)"

    # Initialize live.log for this execution
    echo -e "\n\n=== Loop #$loop_count - $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LIVE_LOG_FILE"

    local exit_code=0

    if [[ "$LIVE_OUTPUT" == "true" ]]; then
        # Live streaming mode (requires jq + stdbuf)
        if ! command -v jq &>/dev/null; then
            log_status "ERROR" "Live mode requires 'jq'. Falling back to background mode."
            LIVE_OUTPUT=false
        elif ! command -v stdbuf &>/dev/null; then
            log_status "ERROR" "Live mode requires 'stdbuf'. Falling back to background mode."
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
            else
                empty
            end'

        set -o pipefail
        portable_timeout ${timeout_seconds}s stdbuf -oL "${LIVE_CMD_ARGS[@]}" \
            2>&1 | stdbuf -oL tee "$output_file" | stdbuf -oL jq --unbuffered -j "$jq_filter" 2>/dev/null | tee "$LIVE_LOG_FILE"

        local -a pipe_status=("${PIPESTATUS[@]}")
        set +o pipefail
        exit_code=${pipe_status[0]}

        [[ ${pipe_status[1]:-0} -ne 0 ]] && log_status "WARN" "Failed to write stream output to log file"
        [[ ${pipe_status[2]:-0} -ne 0 ]] && log_status "WARN" "jq filter had issues parsing some stream events"

        echo ""
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━ End of Output ━━━━━━━━━━━━━━━━━━━${NC}"

        # Extract session from stream-json output
        if [[ "$CLAUDE_USE_CONTINUE" == "true" && -f "$output_file" ]]; then
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

        while kill -0 $claude_pid 2>/dev/null; do
            progress_counter=$((progress_counter + 1))

            local last_line=""
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                last_line=$(tail -1 "$output_file" 2>/dev/null | head -c 80)
                cp "$output_file" "$LIVE_LOG_FILE" 2>/dev/null
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
            sleep 10
        done

        wait $claude_pid
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        # Only increment counter on success
        echo "$calls_made" > "$CALL_COUNT_FILE"

        echo '{"status": "completed", "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'"}' > "$PROGRESS_FILE"
        log_status "SUCCESS" "Claude Code execution completed"

        # Save session for continuity
        if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
            save_claude_session "$output_file"
        fi

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

                if [[ -n "$loop_start_sha" && -n "$current_sha" && "$loop_start_sha" != "$current_sha" ]]; then
                    files_changed=$(
                        {
                            git diff --name-only "$loop_start_sha" "$current_sha" 2>/dev/null
                            git diff --name-only HEAD 2>/dev/null
                            git diff --name-only --cached 2>/dev/null
                        } | sort -u | wc -l
                    )
                else
                    files_changed=$(
                        {
                            git diff --name-only 2>/dev/null
                            git diff --name-only --cached 2>/dev/null
                        } | sort -u | wc -l
                    )
                fi
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
        echo '{"status": "failed", "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'"}' > "$PROGRESS_FILE"

        if grep -qi "5.*hour.*limit\|limit.*reached.*try.*back\|usage.*limit.*reached" "$output_file" 2>/dev/null; then
            log_status "ERROR" "Claude API 5-hour usage limit reached"
            return 2
        fi

        log_status "ERROR" "Claude Code execution failed, check: $output_file"
        return 1
    fi
}

# =============================================================================
# GRACEFUL EXIT DETECTION
# =============================================================================

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

# =============================================================================
# TMUX MONITORING
# =============================================================================

check_tmux_available() {
    if ! command -v tmux &>/dev/null; then
        log_status "ERROR" "tmux is not installed."
        echo "Install tmux: brew install tmux (macOS) or sudo apt-get install tmux (Linux)"
        exit 1
    fi
}

setup_tmux_session() {
    local session_name="super-ralph-$(date +%s)"
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
    tmux send-keys -t "$session_name:${base_win}.2" "watch -n 5 'cat $project_dir/$STATUS_FILE 2>/dev/null | jq . 2>/dev/null || echo No status yet'" Enter

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
        fi
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

    while true; do
        loop_count=$((loop_count + 1))
        update_session_last_used

        log_status "LOOP" "=== Starting Loop #$loop_count ==="

        # Check circuit breaker
        if type should_halt_execution &>/dev/null 2>&1; then
            if should_halt_execution; then
                reset_session "circuit_breaker_open"
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted" "stagnation_detected"
                log_status "ERROR" "Circuit breaker has opened - execution halted"
                log_status "INFO" "Run 'super-ralph --reset-circuit' to reset after addressing issues"
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
            reset_session "project_complete"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "graceful_exit" "completed" "$exit_reason"

            log_status "SUCCESS" "Super-Ralph completed! Final stats:"
            log_status "INFO" "  - Total loops: $loop_count"
            log_status "INFO" "  - API calls: $(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")"
            log_status "INFO" "  - Exit reason: $exit_reason"
            break
        fi

        # Execute with superpowers methodology
        local calls_made
        calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
        update_status "$loop_count" "$calls_made" "executing" "running"

        execute_super_ralph "$loop_count"
        local exec_result=$?

        if [[ $exec_result -eq 0 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "completed" "success"
            sleep 5
        elif [[ $exec_result -eq 3 ]]; then
            reset_session "circuit_breaker_trip"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted" "stagnation_detected"
            log_status "ERROR" "Circuit breaker opened - halting"
            log_status "INFO" "Run 'super-ralph --reset-circuit' to reset"
            break
        elif [[ $exec_result -eq 2 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "api_limit" "paused"
            log_status "WARN" "Claude API 5-hour limit reached!"
            echo -e "\n${YELLOW}The Claude API 5-hour usage limit has been reached.${NC}"
            echo -e "  ${GREEN}1)${NC} Wait for the limit to reset (usually within an hour)"
            echo -e "  ${GREEN}2)${NC} Exit the loop and try again later"
            echo -e "\n${BLUE}Choose an option (1 or 2):${NC} "

            read -t 30 -n 1 user_choice
            echo

            if [[ "$user_choice" == "2" ]] || [[ -z "$user_choice" ]]; then
                log_status "INFO" "User chose to exit (or timed out). Exiting loop..."
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "api_limit_exit" "stopped" "api_5hour_limit"
                break
            else
                log_status "INFO" "User chose to wait. Waiting 60 minutes before retrying..."
                local wait_seconds=3600
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
            log_status "WARN" "Execution failed, waiting 30 seconds before retry..."
            sleep 30
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
                cat "$STATUS_FILE" | jq . 2>/dev/null || cat "$STATUS_FILE"
                if [[ -f "$METHODOLOGY_FILE" ]]; then
                    echo ""
                    echo "Methodology State:"
                    cat "$METHODOLOGY_FILE" | jq . 2>/dev/null || cat "$METHODOLOGY_FILE"
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
