#!/usr/bin/env bash

# skill_selector.sh - Task Classification and Skill Selection for Super-Ralph
# Analyzes fix_plan.md tasks and determines which super-ralph skill to invoke

SUPER_RALPH_DIR="${SUPER_RALPH_DIR:-.ralph}"

# Classify a task line from fix_plan.md into a task type
# Returns: FEATURE | BUG | PLAN_TASK | COMPLETION | REVIEW | UNKNOWN
classify_task() {
    local task_text="$1"
    local task_lower
    task_lower=$(echo "$task_text" | tr '[:upper:]' '[:lower:]')

    # Check for bug/fix patterns
    if echo "$task_lower" | grep -qE '(fix|bug|error|broken|failing|crash|regression|issue|defect)'; then
        echo "BUG"
        return 0
    fi

    # Check for review patterns
    if echo "$task_lower" | grep -qE '(review|feedback|pr comment|code review)'; then
        echo "REVIEW"
        return 0
    fi

    # Check for new feature patterns
    if echo "$task_lower" | grep -qE '(add|create|implement|build|new|feature|introduce|setup|initialize)'; then
        echo "FEATURE"
        return 0
    fi

    # Check for refactor/improvement patterns (treated as plan tasks with TDD)
    if echo "$task_lower" | grep -qE '(refactor|improve|optimize|update|migrate|upgrade|clean)'; then
        echo "PLAN_TASK"
        return 0
    fi

    # Check for documentation/completion patterns
    if echo "$task_lower" | grep -qE '(document|readme|complete|finalize|release|deploy)'; then
        echo "COMPLETION"
        return 0
    fi

    # Default: treat as a plan task (will use TDD)
    echo "PLAN_TASK"
}

# Get the skill workflow for a task type
# Returns a colon-separated list of skills to invoke in order
get_skill_workflow() {
    local task_type="$1"

    case "$task_type" in
        "FEATURE")
            echo "brainstorming:writing-plans:using-git-worktrees:test-driven-development"
            ;;
        "BUG")
            echo "systematic-debugging:test-driven-development"
            ;;
        "PLAN_TASK")
            echo "test-driven-development"
            ;;
        "REVIEW")
            echo "receiving-code-review"
            ;;
        "COMPLETION")
            echo "verification-before-completion:finishing-a-development-branch"
            ;;
        *)
            echo "test-driven-development"
            ;;
    esac
}

# Get the first uncompleted task from fix_plan.md
# Returns the task text or empty string
get_current_task() {
    local fix_plan="$SUPER_RALPH_DIR/fix_plan.md"

    if [[ ! -f "$fix_plan" ]]; then
        echo ""
        return 1
    fi

    # Find first uncompleted checkbox item
    grep -m1 -E "^[[:space:]]*- \[ \]" "$fix_plan" 2>/dev/null | sed 's/^[[:space:]]*- \[ \] //'
}

# Check if a design document exists for a feature
# Returns 0 if exists, 1 if not
has_design_doc() {
    local feature_name="$1"
    local feature_lower
    feature_lower=$(echo "$feature_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

    # Check docs/plans/ for any matching design document
    if ls docs/plans/*"${feature_lower}"*design* 2>/dev/null | head -1 | grep -q .; then
        return 0
    fi

    # Also check for any plan document
    if ls docs/plans/*"${feature_lower}"* 2>/dev/null | head -1 | grep -q .; then
        return 0
    fi

    return 1
}

# Check if an implementation plan exists for a feature
has_implementation_plan() {
    local feature_name="$1"
    local feature_lower
    feature_lower=$(echo "$feature_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

    if ls docs/plans/*"${feature_lower}"*.md 2>/dev/null | grep -v design | head -1 | grep -q .; then
        return 0
    fi

    return 1
}

# Determine the full workflow for the current task
# Returns a human-readable string describing the workflow
describe_workflow() {
    local task_text="$1"
    local task_type
    task_type=$(classify_task "$task_text")
    local skills
    skills=$(get_skill_workflow "$task_type")

    echo "Task type: $task_type"
    echo "Skills: $(echo "$skills" | tr ':' ' -> ')"
}

# Check if all tasks in fix_plan.md are completed
all_tasks_complete() {
    local fix_plan="$SUPER_RALPH_DIR/fix_plan.md"

    if [[ ! -f "$fix_plan" ]]; then
        return 1
    fi

    local uncompleted
    uncompleted=$(grep -cE "^[[:space:]]*- \[ \]" "$fix_plan" 2>/dev/null || true)
    [[ -z "$uncompleted" ]] && uncompleted=0

    local completed
    completed=$(grep -cE "^[[:space:]]*- \[[xX]\]" "$fix_plan" 2>/dev/null || true)
    [[ -z "$completed" ]] && completed=0

    local total=$((uncompleted + completed))

    if [[ $total -gt 0 ]] && [[ $completed -eq $total ]]; then
        return 0
    fi

    return 1
}

# Count remaining tasks
count_remaining_tasks() {
    local fix_plan="$SUPER_RALPH_DIR/fix_plan.md"

    if [[ ! -f "$fix_plan" ]]; then
        echo "0"
        return
    fi

    local uncompleted
    uncompleted=$(grep -cE "^[[:space:]]*- \[ \]" "$fix_plan" 2>/dev/null || true)
    [[ -z "$uncompleted" ]] && uncompleted=0

    echo "$uncompleted"
}

# Export functions
export -f classify_task
export -f get_skill_workflow
export -f get_current_task
export -f has_design_doc
export -f has_implementation_plan
export -f describe_workflow
export -f all_tasks_complete
export -f count_remaining_tasks
