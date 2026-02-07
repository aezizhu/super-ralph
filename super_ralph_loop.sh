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

# Always source Super-Ralph's own libraries
source "$SCRIPT_DIR/lib/skill_selector.sh"
source "$SCRIPT_DIR/lib/tdd_gate.sh"
source "$SCRIPT_DIR/lib/verification_gate.sh"

# If Ralph is installed, source its libraries for infrastructure
if [[ "$RALPH_INSTALLED" == "true" ]]; then
    if [[ -f "$RALPH_HOME/lib/date_utils.sh" ]]; then
        source "$RALPH_HOME/lib/date_utils.sh"
    fi
    if [[ -f "$RALPH_HOME/lib/timeout_utils.sh" ]]; then
        source "$RALPH_HOME/lib/timeout_utils.sh"
    fi
    if [[ -f "$RALPH_HOME/lib/response_analyzer.sh" ]]; then
        source "$RALPH_HOME/lib/response_analyzer.sh"
    fi
    if [[ -f "$RALPH_HOME/lib/circuit_breaker.sh" ]]; then
        source "$RALPH_HOME/lib/circuit_breaker.sh"
    fi
else
    # Standalone mode: provide minimal date utility if Ralph's isn't available
    if ! type get_iso_timestamp &>/dev/null 2>&1; then
        get_iso_timestamp() {
            date -u +"%Y-%m-%dT%H:%M:%S+00:00" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\(..\)$/:\1/'
        }
        get_epoch_seconds() { date +%s; }
        get_next_hour_time() { date -v+1H '+%H:%M:%S' 2>/dev/null || date -d '+1 hour' '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S'; }
        export -f get_iso_timestamp get_epoch_seconds get_next_hour_time
    fi
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

SUPER_RALPH_DIR=".ralph"
PROMPT_FILE="$SUPER_RALPH_DIR/PROMPT.md"
LOG_DIR="$SUPER_RALPH_DIR/logs"
DOCS_DIR="$SUPER_RALPH_DIR/docs/generated"
STATUS_FILE="$SUPER_RALPH_DIR/status.json"
CALL_COUNT_FILE="$SUPER_RALPH_DIR/.call_count"
TIMESTAMP_FILE="$SUPER_RALPH_DIR/.last_reset"
EXIT_SIGNALS_FILE="$SUPER_RALPH_DIR/.exit_signals"
RESPONSE_ANALYSIS_FILE="$SUPER_RALPH_DIR/.response_analysis"
METHODOLOGY_FILE="$SUPER_RALPH_DIR/.methodology_state"
RALPHRC_FILE=".ralphrc"

MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-100}"
CLAUDE_TIMEOUT_MINUTES="${CLAUDE_TIMEOUT_MINUTES:-15}"
CLAUDE_OUTPUT_FORMAT="${CLAUDE_OUTPUT_FORMAT:-json}"
CLAUDE_ALLOWED_TOOLS="${CLAUDE_ALLOWED_TOOLS:-Write,Read,Edit,Bash(git *),Bash(npm *),Bash(pytest),Bash(bats *)}"
CLAUDE_USE_CONTINUE="${CLAUDE_USE_CONTINUE:-true}"
CLAUDE_CODE_CMD="claude"
VERBOSE_PROGRESS="${VERBOSE_PROGRESS:-false}"
USE_TMUX=false
LIVE_OUTPUT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize directories
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
# SUPERPOWERS METHODOLOGY LAYER
# =============================================================================

# Build the superpowers-enhanced system prompt for Claude
# This is injected via --append-system-prompt on every loop iteration
build_superpowers_context() {
    local loop_count=$1
    local task_text="$2"
    local task_type="$3"
    local skills="$4"
    local remaining
    remaining=$(count_remaining_tasks)

    local context="[Super-Ralph Loop #${loop_count}] "
    context+="Remaining tasks: ${remaining}. "

    # Inject task classification
    if [[ -n "$task_type" ]]; then
        context+="Current task type: ${task_type}. "
        context+="Required skills: $(echo "$skills" | tr ':' ', '). "
    fi

    # Inject TDD enforcement
    context+="$(get_tdd_enforcement_context) "

    # Inject verification enforcement
    context+="$(get_verification_enforcement_context) "

    # Add previous loop methodology info
    if [[ -f "$METHODOLOGY_FILE" ]]; then
        local prev_methodology
        prev_methodology=$(jq -r '.methodology // ""' "$METHODOLOGY_FILE" 2>/dev/null)
        local prev_skill
        prev_skill=$(jq -r '.skill_used // ""' "$METHODOLOGY_FILE" 2>/dev/null)
        if [[ -n "$prev_methodology" && "$prev_methodology" != "null" ]]; then
            context+="Previous methodology: ${prev_methodology}. "
        fi
    fi

    # Add circuit breaker state if available
    if [[ -f "$SUPER_RALPH_DIR/.circuit_breaker_state" ]]; then
        local cb_state
        cb_state=$(jq -r '.state // "UNKNOWN"' "$SUPER_RALPH_DIR/.circuit_breaker_state" 2>/dev/null)
        if [[ "$cb_state" != "CLOSED" && "$cb_state" != "null" && -n "$cb_state" ]]; then
            context+="Circuit breaker: ${cb_state}. "
        fi
    fi

    echo "${context:0:800}"
}

# Record the methodology used in this loop iteration
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
# RALPH INFRASTRUCTURE (standalone mode)
# =============================================================================

# These functions provide Ralph's core features when Ralph is not installed.
# When Ralph IS installed, the main loop delegates to Ralph instead.

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
    local current_minute
    current_minute=$(date +%M)
    local current_second
    current_second=$(date +%S)
    local wait_time=$(((60 - current_minute - 1) * 60 + (60 - current_second)))

    log_status "WARN" "Rate limit reached. Waiting $wait_time seconds..."

    while [[ $wait_time -gt 0 ]]; do
        printf "\r${YELLOW}Time until reset: %02d:%02d${NC}" $((wait_time / 60)) $((wait_time % 60))
        sleep 1
        ((wait_time--))
    done
    printf "\n"

    echo "0" > "$CALL_COUNT_FILE"
    echo "$(date +%Y%m%d%H)" > "$TIMESTAMP_FILE"
}

update_status() {
    local loop_count=$1
    local calls_made=$2
    local last_action=$3
    local status=$4
    local exit_reason=${5:-""}

    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(get_iso_timestamp)",
    "loop_count": $loop_count,
    "calls_made_this_hour": $calls_made,
    "max_calls_per_hour": $MAX_CALLS_PER_HOUR,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason",
    "mode": "super-ralph"
}
EOF
}

# Load .ralphrc if it exists
load_ralphrc() {
    if [[ -f "$RALPHRC_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$RALPHRC_FILE"
        [[ -n "${ALLOWED_TOOLS:-}" ]] && CLAUDE_ALLOWED_TOOLS="$ALLOWED_TOOLS"
        [[ -n "${RALPH_VERBOSE:-}" ]] && VERBOSE_PROGRESS="$RALPH_VERBOSE"
    fi
}

# =============================================================================
# SUPERPOWERS-ENHANCED EXECUTION
# =============================================================================

# Execute Claude Code with superpowers methodology context
execute_super_ralph() {
    local loop_count=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"

    # Classify the current task
    local task_text
    task_text=$(get_current_task)
    local task_type=""
    local skills=""

    if [[ -n "$task_text" ]]; then
        task_type=$(classify_task "$task_text")
        skills=$(get_skill_workflow "$task_type")
        log_status "SKILL" "Task: '$task_text'"
        log_status "SKILL" "Type: $task_type | Skills: $(echo "$skills" | tr ':' ' -> ')"
    elif all_tasks_complete 2>/dev/null; then
        task_type="COMPLETION"
        skills="verification-before-completion:finishing-a-development-branch"
        log_status "SKILL" "All tasks complete - entering verification phase"
    fi

    # Record methodology
    local methodology="TDD"
    case "$task_type" in
        "FEATURE") methodology="BRAINSTORMING" ;;
        "BUG") methodology="DEBUGGING" ;;
        "COMPLETION") methodology="VERIFICATION" ;;
        "REVIEW") methodology="REVIEW" ;;
    esac
    record_methodology "$methodology" "$(echo "$skills" | cut -d: -f1)" "$loop_count"

    # Build superpowers context
    local superpowers_context
    superpowers_context=$(build_superpowers_context "$loop_count" "$task_text" "$task_type" "$skills")

    # Capture git HEAD SHA for progress detection
    local loop_start_sha=""
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
        loop_start_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
    fi
    echo "$loop_start_sha" > "$SUPER_RALPH_DIR/.loop_start_sha"

    local calls_made
    calls_made=$(increment_call_counter)
    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))

    log_status "LOOP" "Executing Claude Code (Call $calls_made/$MAX_CALLS_PER_HOUR, timeout: ${CLAUDE_TIMEOUT_MINUTES}m)"

    # Build command arguments
    local -a cmd_args=("$CLAUDE_CODE_CMD")

    if [[ "$CLAUDE_OUTPUT_FORMAT" == "json" ]]; then
        cmd_args+=("--output-format" "json")
    fi

    if [[ -n "$CLAUDE_ALLOWED_TOOLS" ]]; then
        cmd_args+=("--allowedTools")
        local IFS=','
        read -ra tools_array <<< "$CLAUDE_ALLOWED_TOOLS"
        for tool in "${tools_array[@]}"; do
            tool=$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$tool" ]] && cmd_args+=("$tool")
        done
    fi

    # Inject superpowers context
    cmd_args+=("--append-system-prompt" "$superpowers_context")

    # Read prompt and pass via -p
    if [[ -f "$PROMPT_FILE" ]]; then
        local prompt_content
        prompt_content=$(cat "$PROMPT_FILE")
        cmd_args+=("-p" "$prompt_content")
    else
        log_status "ERROR" "Prompt file not found: $PROMPT_FILE"
        return 1
    fi

    # Execute with timeout
    local exit_code=0

    if type portable_timeout &>/dev/null 2>&1; then
        portable_timeout ${timeout_seconds}s "${cmd_args[@]}" > "$output_file" 2>&1 &
    elif command -v gtimeout &>/dev/null; then
        gtimeout ${timeout_seconds}s "${cmd_args[@]}" > "$output_file" 2>&1 &
    elif command -v timeout &>/dev/null; then
        timeout ${timeout_seconds}s "${cmd_args[@]}" > "$output_file" 2>&1 &
    else
        "${cmd_args[@]}" > "$output_file" 2>&1 &
    fi

    local claude_pid=$!
    local progress_counter=0

    while kill -0 $claude_pid 2>/dev/null; do
        progress_counter=$((progress_counter + 1))
        if [[ "$VERBOSE_PROGRESS" == "true" ]]; then
            log_status "INFO" "Claude Code working... (${progress_counter}0s elapsed)"
        fi
        sleep 10
    done

    wait $claude_pid
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_status "SUCCESS" "Claude Code execution completed"

        # Run superpowers post-execution checks
        log_status "SKILL" "Running TDD compliance check..."
        analyze_tdd_status "$output_file"
        log_tdd_summary

        log_status "SKILL" "Running verification gate..."
        analyze_verification_status "$output_file"
        log_verification_summary

        # Run Ralph's response analyzer if available
        if type analyze_response &>/dev/null 2>&1; then
            analyze_response "$output_file" "$loop_count"
            if type update_exit_signals &>/dev/null 2>&1; then
                update_exit_signals
            fi
            if type log_analysis_summary &>/dev/null 2>&1; then
                log_analysis_summary
            fi
        fi

        # Record circuit breaker result if available
        if type record_loop_result &>/dev/null 2>&1; then
            local files_changed=0
            if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
                files_changed=$(git diff --name-only 2>/dev/null | wc -l)
                local staged
                staged=$(git diff --name-only --cached 2>/dev/null | wc -l)
                files_changed=$((files_changed + staged))
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
                log_status "WARN" "Circuit breaker opened"
                return 3
            fi
        fi

        return 0
    else
        if grep -qi "5.*hour.*limit\|limit.*reached.*try.*back\|usage.*limit.*reached" "$output_file" 2>/dev/null; then
            log_status "ERROR" "Claude API 5-hour limit reached"
            return 2
        fi
        log_status "ERROR" "Claude Code execution failed, check: $output_file"
        return 1
    fi
}

# Check graceful exit conditions
should_exit_gracefully() {
    # Check fix_plan.md completion
    if all_tasks_complete 2>/dev/null; then
        # Validate exit signal with verification gate
        if [[ -f "$RESPONSE_ANALYSIS_FILE" ]]; then
            local exit_signal
            exit_signal=$(jq -r '.analysis.exit_signal // false' "$RESPONSE_ANALYSIS_FILE" 2>/dev/null || echo "false")
            if [[ "$exit_signal" == "true" ]]; then
                local verified
                verified=$(validate_exit_signal "$RESPONSE_ANALYSIS_FILE")
                if [[ "$verified" == "true" ]]; then
                    echo "project_complete_verified"
                    return 0
                else
                    log_status "WARN" "EXIT_SIGNAL=true but verification gate failed - continuing" >&2
                fi
            fi
        fi

        # All tasks complete but no exit signal yet
        echo "plan_complete"
        return 0
    fi

    # Delegate to Ralph's exit detection if available
    if [[ -f "$EXIT_SIGNALS_FILE" ]]; then
        local signals
        signals=$(cat "$EXIT_SIGNALS_FILE")
        local test_loops
        test_loops=$(echo "$signals" | jq '.test_only_loops | length' 2>/dev/null || echo "0")
        if [[ $test_loops -ge 3 ]]; then
            echo "test_saturation"
            return 0
        fi
    fi

    echo ""
}

# =============================================================================
# SIGNAL HANDLING
# =============================================================================

loop_count=0

cleanup() {
    log_status "INFO" "Super-Ralph loop interrupted. Cleaning up..."
    update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "interrupted" "stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    load_ralphrc

    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Super-Ralph: Superpowers-Enhanced Development      ║"
    echo "║                                                             ║"
    echo "║  Brainstorm -> Plan -> TDD -> Review -> Verify              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ "$RALPH_INSTALLED" == "true" ]]; then
        log_status "INFO" "Mode: Ralph extension (Ralph infrastructure detected)"
    else
        log_status "INFO" "Mode: Standalone (using built-in infrastructure)"
    fi

    log_status "SUCCESS" "Super-Ralph loop starting"
    log_status "INFO" "Max calls/hour: $MAX_CALLS_PER_HOUR | Timeout: ${CLAUDE_TIMEOUT_MINUTES}m"

    # Verify project structure
    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_status "ERROR" "Prompt file '$PROMPT_FILE' not found!"
        echo ""
        echo "To fix: run 'super-ralph-setup my-project' or create .ralph/PROMPT.md"
        exit 1
    fi

    init_call_tracking

    while true; do
        loop_count=$((loop_count + 1))
        log_status "LOOP" "=== Super-Ralph Loop #$loop_count ==="

        # Check circuit breaker
        if type should_halt_execution &>/dev/null 2>&1; then
            if should_halt_execution; then
                update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted"
                log_status "ERROR" "Circuit breaker opened - halting"
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
            log_status "SUCCESS" "Graceful exit: $exit_reason"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "graceful_exit" "completed" "$exit_reason"
            log_status "SUCCESS" "Super-Ralph completed! Total loops: $loop_count"
            break
        fi

        # Execute with superpowers methodology
        update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "executing" "running"

        execute_super_ralph "$loop_count"
        local exec_result=$?

        if [[ $exec_result -eq 0 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "completed" "success"
            sleep 5
        elif [[ $exec_result -eq 3 ]]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "circuit_breaker_open" "halted"
            log_status "ERROR" "Circuit breaker opened - halting"
            break
        elif [[ $exec_result -eq 2 ]]; then
            log_status "ERROR" "API limit reached. Exiting."
            break
        else
            log_status "WARN" "Execution failed, retrying in 30s..."
            sleep 30
        fi

        log_status "LOOP" "=== Completed Loop #$loop_count ==="
    done
}

# =============================================================================
# CLI ARGUMENT PARSING
# =============================================================================

show_help() {
    cat << EOF
Super-Ralph: Superpowers-Enhanced Autonomous Development

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help
    -c, --calls NUM         Max API calls per hour (default: $MAX_CALLS_PER_HOUR)
    -p, --prompt FILE       Prompt file (default: $PROMPT_FILE)
    -s, --status            Show current status
    -v, --verbose           Verbose progress output
    -l, --live              Live streaming output
    -t, --timeout MIN       Execution timeout in minutes (default: $CLAUDE_TIMEOUT_MINUTES)
    -m, --monitor           Start with tmux monitoring
    --reset-circuit         Reset circuit breaker
    --reset-session         Reset session state
    --no-continue           Disable session continuity
    --output-format FORMAT  json or text (default: $CLAUDE_OUTPUT_FORMAT)
    --allowed-tools TOOLS   Comma-separated tool list

Superpowers Features:
    - Automatic task classification (feature/bug/plan/completion)
    - TDD enforcement gate (test-first methodology)
    - Verification gate (evidence before completion claims)
    - Skill-based workflow selection (brainstorming, debugging, etc.)
    - Two-stage code review (spec compliance + quality)

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -c|--calls) MAX_CALLS_PER_HOUR="$2"; shift 2 ;;
        -p|--prompt) PROMPT_FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE_PROGRESS=true; shift ;;
        -l|--live) LIVE_OUTPUT=true; shift ;;
        -t|--timeout) CLAUDE_TIMEOUT_MINUTES="$2"; shift 2 ;;
        -m|--monitor) USE_TMUX=true; shift ;;
        --no-continue) CLAUDE_USE_CONTINUE=false; shift ;;
        --output-format) CLAUDE_OUTPUT_FORMAT="$2"; shift 2 ;;
        --allowed-tools) CLAUDE_ALLOWED_TOOLS="$2"; shift 2 ;;
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
                reset_circuit_breaker "Manual reset"
            fi
            echo -e "${GREEN}Circuit breaker reset${NC}"
            exit 0
            ;;
        --reset-session)
            rm -f "$SUPER_RALPH_DIR/.claude_session_id" "$SUPER_RALPH_DIR/.ralph_session" "$EXIT_SIGNALS_FILE" "$RESPONSE_ANALYSIS_FILE"
            echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
            echo -e "${GREEN}Session state reset${NC}"
            exit 0
            ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
