#!/usr/bin/env bats

# Tests for skill_selector.sh - Task Classification and Skill Selection

setup() {
    export SUPER_RALPH_DIR="$BATS_TMPDIR/ralph_test_$$"
    mkdir -p "$SUPER_RALPH_DIR"
    source "$BATS_TEST_DIRNAME/../standalone/lib/skill_selector.sh"
}

teardown() {
    rm -rf "$SUPER_RALPH_DIR"
}

# ============================================================================
# classify_task tests
# ============================================================================

@test "classify_task: 'fix login bug' returns BUG" {
    result=$(classify_task "fix login bug")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'Fix crash on startup' returns BUG" {
    result=$(classify_task "Fix crash on startup")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'resolve failing test regression' returns BUG" {
    result=$(classify_task "resolve failing test regression")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'add user authentication' returns FEATURE" {
    result=$(classify_task "add user authentication")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'Create new API endpoint' returns FEATURE" {
    result=$(classify_task "Create new API endpoint")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'implement rate limiting' returns FEATURE" {
    result=$(classify_task "implement rate limiting")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'build dashboard component' returns FEATURE" {
    result=$(classify_task "build dashboard component")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'review PR #42' returns REVIEW" {
    result=$(classify_task "review PR #42")
    [ "$result" = "REVIEW" ]
}

@test "classify_task: 'address code review feedback' returns REVIEW" {
    result=$(classify_task "address code review feedback")
    [ "$result" = "REVIEW" ]
}

@test "classify_task: 'refactor database layer' returns PLAN_TASK" {
    result=$(classify_task "refactor database layer")
    [ "$result" = "PLAN_TASK" ]
}

@test "classify_task: 'optimize query performance' returns PLAN_TASK" {
    result=$(classify_task "optimize query performance")
    [ "$result" = "PLAN_TASK" ]
}

@test "classify_task: 'update dependencies' returns PLAN_TASK" {
    result=$(classify_task "update dependencies")
    [ "$result" = "PLAN_TASK" ]
}

@test "classify_task: 'document API endpoints' returns COMPLETION" {
    result=$(classify_task "document API endpoints")
    [ "$result" = "COMPLETION" ]
}

@test "classify_task: 'finalize release v1.0' returns COMPLETION" {
    result=$(classify_task "finalize release v1.0")
    [ "$result" = "COMPLETION" ]
}

@test "classify_task: unknown task defaults to PLAN_TASK" {
    # Note: "completely" matches "complete" pattern -> COMPLETION. Use truly unmatched text.
    result=$(classify_task "do the thing now")
    [ "$result" = "PLAN_TASK" ]
}

@test "classify_task: empty string returns UNKNOWN" {
    result=$(classify_task "" || true)
    [ "$result" = "UNKNOWN" ]
}

# BUG takes priority over FEATURE when both patterns match
@test "classify_task: 'fix by adding new handler' returns BUG (BUG priority)" {
    result=$(classify_task "fix by adding new handler")
    [ "$result" = "BUG" ]
}

# Pattern priority tests - BUG checked before FEATURE, REVIEW, etc.
@test "classify_task: 'fix and add new feature' returns BUG (BUG wins over FEATURE)" {
    result=$(classify_task "fix and add new feature")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'review the bug fix' returns BUG (BUG wins over REVIEW)" {
    result=$(classify_task "review the bug fix")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'create a bug report' returns BUG (BUG wins over FEATURE)" {
    result=$(classify_task "create a bug report")
    [ "$result" = "BUG" ]
}

@test "classify_task: ALL CAPS 'FIX THIS BUG' returns BUG" {
    result=$(classify_task "FIX THIS BUG")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'review and update docs' returns REVIEW (REVIEW wins over PLAN_TASK)" {
    result=$(classify_task "review and update docs")
    [ "$result" = "REVIEW" ]
}

# ============================================================================
# New pattern coverage tests
# ============================================================================

@test "classify_task: 'repair authentication flow' returns BUG" {
    result=$(classify_task "repair authentication flow")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'correct the output format' returns BUG" {
    result=$(classify_task "correct the output format")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'apply hotfix for login' returns BUG" {
    result=$(classify_task "apply hotfix for login")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'patch the security vulnerability' returns BUG" {
    result=$(classify_task "patch the security vulnerability")
    [ "$result" = "BUG" ]
}

@test "classify_task: 'enhance logging output' returns FEATURE" {
    result=$(classify_task "enhance logging output")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'extend API with new endpoint' returns FEATURE" {
    result=$(classify_task "extend API with new endpoint")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: 'expand test coverage' returns FEATURE" {
    result=$(classify_task "expand test coverage")
    [ "$result" = "FEATURE" ]
}

@test "classify_task: whitespace-only input returns UNKNOWN" {
    run classify_task "   "
    [ "$status" -eq 1 ]
    [[ "$output" == *"UNKNOWN"* ]]
}

# ============================================================================
# all_tasks_complete edge cases
# ============================================================================

@test "all_tasks_complete: false when fix_plan is empty" {
    touch "$SUPER_RALPH_DIR/fix_plan.md"
    run all_tasks_complete
    [ "$status" -eq 1 ]
}

@test "all_tasks_complete: false when fix_plan has no checkboxes" {
    echo "# Just a heading" > "$SUPER_RALPH_DIR/fix_plan.md"
    run all_tasks_complete
    [ "$status" -eq 1 ]
}

# ============================================================================
# get_skill_workflow tests
# ============================================================================

@test "get_skill_workflow: FEATURE returns brainstorming-first workflow" {
    result=$(get_skill_workflow "FEATURE")
    [[ "$result" == *"brainstorming"* ]]
    [[ "$result" == *"test-driven-development"* ]]
}

@test "get_skill_workflow: BUG returns debugging-first workflow" {
    result=$(get_skill_workflow "BUG")
    [[ "$result" == *"systematic-debugging"* ]]
}

@test "get_skill_workflow: PLAN_TASK returns TDD workflow" {
    result=$(get_skill_workflow "PLAN_TASK")
    [[ "$result" == *"test-driven-development"* ]]
}

@test "get_skill_workflow: COMPLETION returns verification workflow" {
    result=$(get_skill_workflow "COMPLETION")
    [[ "$result" == *"verification"* ]]
}

@test "get_skill_workflow: REVIEW returns code review workflow" {
    result=$(get_skill_workflow "REVIEW")
    [[ "$result" == *"receiving-code-review"* ]]
}

@test "get_skill_workflow: UNKNOWN defaults to TDD" {
    result=$(get_skill_workflow "UNKNOWN")
    [[ "$result" == *"test-driven-development"* ]]
}

# ============================================================================
# get_current_task tests
# ============================================================================

@test "get_current_task: returns first uncompleted task" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
# Fix Plan
- [x] Completed task
- [ ] First uncompleted task
- [ ] Second uncompleted task
EOF
    result=$(get_current_task)
    [ "$result" = "First uncompleted task" ]
}

@test "get_current_task: returns empty when all tasks complete" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
# Fix Plan
- [x] Done task 1
- [x] Done task 2
EOF
    result=$(get_current_task)
    [ -z "$result" ]
}

@test "get_current_task: returns empty when no fix_plan exists" {
    # get_current_task returns exit code 1 when file missing, capture with || true
    result=$(get_current_task || true)
    [ -z "$result" ]
}

# ============================================================================
# all_tasks_complete tests
# ============================================================================

@test "all_tasks_complete: true when all checked" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
- [x] Task 1
- [X] Task 2
EOF
    run all_tasks_complete
    [ "$status" -eq 0 ]
}

@test "all_tasks_complete: false when unchecked items remain" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
- [x] Task 1
- [ ] Task 2
EOF
    run all_tasks_complete
    [ "$status" -eq 1 ]
}

@test "all_tasks_complete: false when no fix_plan" {
    run all_tasks_complete
    [ "$status" -eq 1 ]
}

# ============================================================================
# count_remaining_tasks tests
# ============================================================================

@test "count_remaining_tasks: counts unchecked items" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
- [x] Done
- [ ] Todo 1
- [ ] Todo 2
- [ ] Todo 3
EOF
    result=$(count_remaining_tasks)
    [ "$result" = "3" ]
}

@test "count_remaining_tasks: returns 0 when all done" {
    cat > "$SUPER_RALPH_DIR/fix_plan.md" << 'EOF'
- [x] Done 1
- [x] Done 2
EOF
    result=$(count_remaining_tasks)
    [ "$result" = "0" ]
}

@test "count_remaining_tasks: returns 0 when no file" {
    result=$(count_remaining_tasks)
    [ "$result" = "0" ]
}

# ============================================================================
# describe_workflow tests
# ============================================================================

@test "describe_workflow: includes task type and skills" {
    result=$(describe_workflow "fix login bug")
    [[ "$result" == *"BUG"* ]]
    [[ "$result" == *"systematic-debugging"* ]]
}

@test "describe_workflow: shows FEATURE workflow" {
    result=$(describe_workflow "add new dashboard")
    [[ "$result" == *"FEATURE"* ]]
    [[ "$result" == *"brainstorming"* ]]
}

# ============================================================================
# has_design_doc tests
# ============================================================================

@test "has_design_doc: returns 1 when no docs directory" {
    run has_design_doc "my-feature"
    [ "$status" -eq 1 ]
}

@test "has_design_doc: returns 0 when matching design doc exists" {
    mkdir -p docs/plans
    touch "docs/plans/2026-01-01-my-feature-design.md"
    run has_design_doc "my feature"
    [ "$status" -eq 0 ]
    rm -rf docs
}

@test "has_implementation_plan: returns 1 when no docs" {
    run has_implementation_plan "my-feature"
    [ "$status" -eq 1 ]
}
