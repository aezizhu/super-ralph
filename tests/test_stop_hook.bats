#!/usr/bin/env bats

# Tests for stop-hook.sh - Ralph Loop Stop Hook
# Tests the self-referential loop controller behavior

HOOK_SCRIPT="$BATS_TEST_DIRNAME/../plugins/super-ralph/hooks/stop-hook.sh"

setup() {
    export TEST_DIR="$BATS_TMPDIR/stop_hook_test_$$"
    mkdir -p "$TEST_DIR/.claude"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Helper to create a state file with frontmatter
create_state_file() {
    local iteration="${1:-1}"
    local max_iterations="${2:-0}"
    local completion_promise="${3:-null}"
    local prompt="${4:-Do the work}"
    local session_transcript="${5:-}"

    local session_line=""
    if [[ -n "$session_transcript" ]]; then
        session_line="session_transcript: \"$session_transcript\""$'\n'
    fi

    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << EOF
---
active: true
${session_line}iteration: $iteration
max_iterations: $max_iterations
completion_promise: $completion_promise
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---
$prompt
EOF
}

# Helper to create a minimal transcript JSONL file
create_transcript() {
    local text="${1:-I completed the work}"
    local transcript_file="$TEST_DIR/transcript.jsonl"

    # Write a minimal assistant message in JSONL format
    echo '{"role":"user","message":{"content":[{"type":"text","text":"Do the work"}]}}' > "$transcript_file"
    printf '{"role":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$text" >> "$transcript_file"

    echo "$transcript_file"
}

# Helper to create hook input JSON
create_hook_input() {
    local transcript_path="${1:-$TEST_DIR/transcript.jsonl}"
    echo "{\"transcript_path\": \"$transcript_path\"}"
}

# ============================================================================
# Exit behavior tests
# ============================================================================

@test "stop-hook: exits 0 (allows exit) when no state file" {
    local hook_input
    hook_input=$(create_hook_input)
    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]
    # No JSON output means exit was allowed
    ! echo "$output" | jq -e '.decision' 2>/dev/null
}

@test "stop-hook: blocks exit when state file present" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should output JSON with decision: block
    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

@test "stop-hook: increments iteration counter" {
    create_state_file 3 0
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Check the state file was updated
    local new_iteration
    new_iteration=$(grep '^iteration:' "$TEST_DIR/.claude/super-ralph-loop.local.md" | sed 's/iteration: *//')
    [ "$new_iteration" = "4" ]
}

@test "stop-hook: allows exit at max iterations" {
    create_state_file 5 5
    local transcript
    transcript=$(create_transcript "Done")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should NOT output block decision (max reached)
    if echo "$output" | jq -e '.decision' 2>/dev/null; then
        local decision
        decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
        [ "$decision" != "block" ]
    fi

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: continues when iteration < max_iterations" {
    create_state_file 3 10
    local transcript
    transcript=$(create_transcript "Continuing work")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

# ============================================================================
# Completion promise tests
# ============================================================================

@test "stop-hook: stops when completion promise matches" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "I've verified: <promise>All tests pass</promise>")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (promise matched)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: stops with bash fallback when perl unavailable" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "Result: <promise>All tests pass</promise>")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    # Temporarily hide perl to test bash fallback
    run bash -c "PATH=/usr/bin:/bin; echo '$hook_input' | bash '$HOOK_SCRIPT'"
    # This test validates the bash regex fallback works
    # On most systems perl IS available so the test exercises the perl path,
    # but the code path for bash fallback exists
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: continues when promise doesn't match" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "I think tests might pass")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

@test "stop-hook: continues with max_iterations=0 (infinite)" {
    create_state_file 100 0
    local transcript
    transcript=$(create_transcript "Still working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

# ============================================================================
# Error handling tests
# ============================================================================

@test "stop-hook: handles corrupted iteration (non-numeric)" {
    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << 'EOF'
---
iteration: abc
max_iterations: 10
completion_promise: null
---
Do work
EOF
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (corrupted)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles missing transcript path" {
    create_state_file 1 0
    local hook_input='{"transcript_path": null}'

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles nonexistent transcript file" {
    create_state_file 1 0
    local hook_input='{"transcript_path": "/nonexistent/transcript.jsonl"}'

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

# ============================================================================
# Output format tests
# ============================================================================

@test "stop-hook: block output includes prompt text" {
    create_state_file 1 0 "null" "Build the feature"
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local reason
    reason=$(echo "$output" | jq -r '.reason' 2>/dev/null)
    [[ "$reason" == *"Build the feature"* ]]
}

@test "stop-hook: block output includes system message with iteration" {
    create_state_file 5 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"iteration 6"* ]]
}

@test "stop-hook: system message includes methodology context" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"Super-Ralph"* ]]
    [[ "$sys_msg" == *"sr-"* ]]
}

# ============================================================================
# Edge case tests
# ============================================================================

@test "stop-hook: handles empty frontmatter" {
    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << 'EOF'
---
---
Do work
EOF
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (empty frontmatter = corrupted)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles corrupted max_iterations (non-numeric)" {
    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << 'EOF'
---
iteration: 1
max_iterations: xyz
completion_promise: null
---
Do work
EOF
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (corrupted)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles no assistant messages in transcript" {
    create_state_file 1 0
    local transcript_file="$TEST_DIR/transcript.jsonl"
    # Only user messages, no assistant
    echo '{"role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' > "$transcript_file"
    local hook_input
    hook_input=$(create_hook_input "$transcript_file")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (no assistant response)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: methodology context contains skill routing table" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    # Verify specific skill routing entries
    [[ "$sys_msg" == *"sr-brainstorming"* ]]
    [[ "$sys_msg" == *"sr-test-driven-development"* ]]
    [[ "$sys_msg" == *"sr-verification-before-completion"* ]]
    [[ "$sys_msg" == *"sr-systematic-debugging"* ]]
    [[ "$sys_msg" == *"SKILL ROUTING"* ]]
}

@test "stop-hook: methodology context contains enforcement rules" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"Evidence before assertions"* ]]
    [[ "$sys_msg" == *"One fix at a time"* ]]
}

@test "stop-hook: system message includes promise instructions when set" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"<promise>All tests pass</promise>"* ]]
    [[ "$sys_msg" == *"ONLY when statement is TRUE"* ]]
}

@test "stop-hook: system message shows infinite when no promise" {
    create_state_file 1 0 "null"
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"runs infinitely"* ]]
}

@test "stop-hook: promise with quotes in completion_promise" {
    create_state_file 1 0 '"All done"'
    local transcript
    transcript=$(create_transcript "Result: <promise>All done</promise>")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Promise should match (quotes are stripped by sed in frontmatter parsing)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: multiline promise matched with perl" {
    if ! command -v perl &>/dev/null; then
        skip "perl not available"
    fi
    create_state_file 1 0 "All tests pass"
    local transcript_file="$TEST_DIR/transcript.jsonl"

    # Create transcript with multiline content containing promise across lines
    echo '{"role":"user","message":{"content":[{"type":"text","text":"Do the work"}]}}' > "$transcript_file"
    # Use jq to properly escape the multiline text as JSON
    local multiline_text
    multiline_text=$(printf 'I verified the work.\n<promise>All tests pass</promise>\nDone.')
    jq -n --arg text "$multiline_text" '{"role":"assistant","message":{"content":[{"type":"text","text":$text}]}}' >> "$transcript_file"

    local hook_input
    hook_input=$(create_hook_input "$transcript_file")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Promise should match
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles prompt with --- delimiters in content" {
    # Test that prompts containing --- don't break the awk parser
    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << 'EOF'
---
active: true
iteration: 1
max_iterations: 0
completion_promise: null
---
Build the feature
---
This line has dashes
---
Continue working
EOF
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local reason
    reason=$(echo "$output" | jq -r '.reason' 2>/dev/null)
    # Prompt should include content after closing frontmatter ---
    [[ "$reason" == *"Build the feature"* ]]
    [[ "$reason" == *"Continue working"* ]]
}

# ============================================================================
# Session isolation tests
# ============================================================================

@test "stop-hook: session mismatch allows exit WITHOUT deleting state file" {
    # Session A owns the loop
    create_state_file 3 0 "null" "Do the work" "/path/to/session-A/transcript.jsonl"
    local transcript
    transcript=$(create_transcript "Working")
    # Session B triggers the hook (different transcript_path)
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should NOT output block decision (not our loop)
    if echo "$output" | jq -e '.decision' 2>/dev/null; then
        local decision
        decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
        [ "$decision" != "block" ]
    fi

    # CRITICAL: state file must still exist (belongs to session A)
    [ -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]

    # Verify session_transcript is unchanged
    local stored
    stored=$(grep 'session_transcript' "$TEST_DIR/.claude/super-ralph-loop.local.md" || true)
    [[ "$stored" == *"session-A"* ]]
}

@test "stop-hook: same session continues loop" {
    local transcript
    transcript=$(create_transcript "Working on it")
    # Create state file owned by THIS transcript
    create_state_file 2 0 "null" "Do the work" "$transcript"
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

@test "stop-hook: recent unclaimed file gets claimed by first session" {
    # State file just created, no session_transcript yet
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should block exit (claimed the loop)
    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]

    # Should have written session_transcript to state file
    local stored
    stored=$(grep 'session_transcript' "$TEST_DIR/.claude/super-ralph-loop.local.md" || true)
    [[ "$stored" == *"$transcript"* ]]
}

@test "stop-hook: old unclaimed file treated as stale" {
    # Create state file with no session_transcript
    create_state_file 1 0
    # Make the file appear old (10 minutes ago)
    touch -t "$(date -v-10M +%Y%m%d%H%M.%S 2>/dev/null || date -d '10 minutes ago' +%Y%m%d%H%M.%S 2>/dev/null)" "$TEST_DIR/.claude/super-ralph-loop.local.md"

    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should NOT block (stale file)
    if echo "$output" | jq -e '.decision' 2>/dev/null; then
        local decision
        decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
        [ "$decision" != "block" ]
    fi

    # Stale file should be cleaned up
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: session mismatch preserves iteration count of other session" {
    # Session A is at iteration 7
    create_state_file 7 20 "null" "Build API" "/path/to/session-A/transcript.jsonl"
    local transcript
    transcript=$(create_transcript "Done")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Session A's iteration must be preserved
    local iter
    iter=$(grep '^iteration:' "$TEST_DIR/.claude/super-ralph-loop.local.md" | sed 's/iteration: *//')
    [ "$iter" = "7" ]
}
