#!/usr/bin/env bats

SCRIPT_DIR="$BATS_TEST_DIRNAME/../plugins/super-ralph/skills/sr-subagent-driven-development/scripts"
SDD_WORKSPACE_SCRIPT="$SCRIPT_DIR/sdd-workspace"
TASK_BRIEF_SCRIPT="$SCRIPT_DIR/task-brief"
REVIEW_PACKAGE_SCRIPT="$SCRIPT_DIR/review-package"

setup() {
    export TEST_DIR="$(mktemp -d "$BATS_TMPDIR/sdd_scripts.XXXXXX")"
    export REPO_DIR="$TEST_DIR/repo"
    mkdir -p "$REPO_DIR"
    git -C "$REPO_DIR" init -q
}

teardown() {
    rm -rf "$TEST_DIR"
}

write_and_commit() {
    local path="$1"
    local content="$2"
    local message="$3"

    printf '%s\n' "$content" > "$REPO_DIR/$path"
    git -C "$REPO_DIR" add "$path"
    git -C "$REPO_DIR" -c user.email=t@t -c user.name=t commit -m "$message" >/dev/null
}

@test "sdd-workspace: prints repo-local workspace path and initializes it" {
    mkdir -p "$REPO_DIR/nested/dir"
    cd "$REPO_DIR/nested/dir"

    run bash "$SDD_WORKSPACE_SCRIPT"
    [ "$status" -eq 0 ]

    local workspace="$REPO_DIR/.superpowers/sdd"
    [ "$output" = "$workspace" ]
    [ -d "$workspace" ]
    [ "$(cat "$workspace/.gitignore")" = "*" ]
}

@test "task-brief: extracts the requested task to an explicit outfile" {
    local plan="$TEST_DIR/plan.md"
    cat > "$plan" <<'EOF'
# Implementation Plan

## Task 1: Prepare the app
Task 1 line 1
Task 1 line 2

## Task 2: Ship the change
Task 2 line 1
Task 2 line 2

## Task 3: Cleanup
Task 3 line 1
EOF

    local out="$TEST_DIR/task-2-brief.md"

    run bash "$TASK_BRIEF_SCRIPT" "$plan" 2 "$out"
    [ "$status" -eq 0 ]
    [ -f "$out" ]

    local actual
    actual=$(cat "$out")
    local expected
    expected=$(cat <<'EOF'
## Task 2: Ship the change
Task 2 line 1
Task 2 line 2
EOF
)
    [ "$actual" = "$expected" ]
}

@test "task-brief: ignores task headings inside fenced code blocks" {
    local plan="$TEST_DIR/plan-fence.md"
    cat > "$plan" <<'EOF'
# Plan

```md
## Task 9: This is only example text
Inside the fence.
```

## Task 1: Real task
Real task line 1
EOF

    local out="$TEST_DIR/task-9-brief.md"

    run bash "$TASK_BRIEF_SCRIPT" "$plan" 9 "$out"
    [ "$status" -eq 3 ]
    [ ! -s "$out" ]
}

@test "task-brief: exits 2 on wrong arg count" {
    run bash "$TASK_BRIEF_SCRIPT"
    [ "$status" -eq 2 ]
}

@test "task-brief: exits 2 when the plan file is missing" {
    local out="$TEST_DIR/missing-brief.md"

    run bash "$TASK_BRIEF_SCRIPT" "$TEST_DIR/no-such-plan.md" 1 "$out"
    [ "$status" -eq 2 ]
}

@test "task-brief: exits 3 when the requested task is not found" {
    local plan="$TEST_DIR/plan-no-match.md"
    cat > "$plan" <<'EOF'
# Plan

## Task 1: Only task
Only task line 1
EOF

    local out="$TEST_DIR/task-4-brief.md"

    run bash "$TASK_BRIEF_SCRIPT" "$plan" 4 "$out"
    [ "$status" -eq 3 ]
    [ ! -s "$out" ]
}

@test "review-package: writes the diff package for a commit range" {
    write_and_commit "note.txt" "base line" "base commit"
    printf '%s\n' "base line" "head line" > "$REPO_DIR/note.txt"
    git -C "$REPO_DIR" add note.txt
    git -C "$REPO_DIR" -c user.email=t@t -c user.name=t commit -m "update note" >/dev/null

    cd "$REPO_DIR"

    local base head base_short head_short out
    base=$(git -C "$REPO_DIR" rev-parse HEAD~1)
    head=$(git -C "$REPO_DIR" rev-parse HEAD)
    base_short=$(git -C "$REPO_DIR" rev-parse --short "$base")
    head_short=$(git -C "$REPO_DIR" rev-parse --short "$head")
    out="$REPO_DIR/.superpowers/sdd/review-${base_short}..${head_short}.diff"

    run bash "$REVIEW_PACKAGE_SCRIPT" "$base" "$head"
    [ "$status" -eq 0 ]

    printf '%s\n' "$output" | grep -F "wrote $out: 1 commit(s),"
    [ -f "$out" ]

    local review
    review=$(cat "$out")
    printf '%s\n' "$review" | grep -F "# Review package: ${base}..${head}"
    printf '%s\n' "$review" | grep -F "## Commits"
    printf '%s\n' "$review" | grep -F "update note"
    printf '%s\n' "$review" | grep -F "## Files changed"
    printf '%s\n' "$review" | grep -F "note.txt | 1 +"
    printf '%s\n' "$review" | grep -F "## Diff"
    printf '%s\n' "$review" | grep -F "+head line"
}
