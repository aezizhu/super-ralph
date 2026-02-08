#!/usr/bin/env bats

# Tests for gate_utils.sh - Shared Gate Utilities

setup() {
    export BATS_TEST_DIR="$BATS_TMPDIR/gate_utils_test_$$"
    mkdir -p "$BATS_TEST_DIR"
    source "$BATS_TEST_DIRNAME/../standalone/lib/gate_utils.sh"
}

teardown() {
    rm -rf "$BATS_TEST_DIR"
}

# ============================================================================
# count_pattern_matches tests
# ============================================================================

@test "count_pattern_matches: counts matching patterns" {
    local patterns=("hello" "world" "foo")
    result=$(count_pattern_matches "hello world" "${patterns[@]}")
    [ "$result" = "2" ]
}

@test "count_pattern_matches: returns 0 for no matches" {
    local patterns=("foo" "bar")
    result=$(count_pattern_matches "hello world" "${patterns[@]}")
    [ "$result" = "0" ]
}

@test "count_pattern_matches: handles regex patterns" {
    local patterns=("[0-9]+ tests? pass" "exit code.*0")
    result=$(count_pattern_matches "42 tests pass and exit code 0" "${patterns[@]}")
    [ "$result" = "2" ]
}

@test "count_pattern_matches: handles empty text" {
    local patterns=("hello")
    result=$(count_pattern_matches "" "${patterns[@]}")
    [ "$result" = "0" ]
}

@test "count_pattern_matches: handles empty pattern array" {
    local patterns=()
    result=$(count_pattern_matches "hello world" "${patterns[@]}")
    [ "$result" = "0" ]
}

# ============================================================================
# collect_pattern_details tests
# ============================================================================

@test "collect_pattern_details: collects matching patterns as JSON array" {
    local patterns=("hello" "world" "missing")
    result=$(collect_pattern_details "hello world" "${patterns[@]}")

    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "2" ]

    local first
    first=$(echo "$result" | jq -r '.[0]')
    [ "$first" = "hello" ]
}

@test "collect_pattern_details: returns empty array for no matches" {
    local patterns=("foo" "bar")
    result=$(collect_pattern_details "hello world" "${patterns[@]}")
    [ "$result" = "[]" ]
}

@test "collect_pattern_details: handles regex matches" {
    local patterns=("[0-9]+ tests")
    result=$(collect_pattern_details "ran 42 tests" "${patterns[@]}")

    local first
    first=$(echo "$result" | jq -r '.[0]')
    [ "$first" = "42 tests" ]
}

@test "collect_pattern_details: handles special characters safely" {
    local patterns=("should pass")
    result=$(collect_pattern_details 'the test should pass "correctly"' "${patterns[@]}")

    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "1" ]
}

# ============================================================================
# read_lowercase tests
# ============================================================================

@test "read_lowercase: converts file content to lowercase" {
    echo "Hello WORLD Mixed" > "$BATS_TEST_DIR/test.txt"
    result=$(read_lowercase "$BATS_TEST_DIR/test.txt")
    [ "$result" = "hello world mixed" ]
}

@test "read_lowercase: returns error for nonexistent file" {
    run read_lowercase "/nonexistent/file"
    [ "$status" -eq 1 ]
}

@test "read_lowercase: handles empty file" {
    touch "$BATS_TEST_DIR/empty.txt"
    result=$(read_lowercase "$BATS_TEST_DIR/empty.txt")
    [ -z "$result" ]
}

@test "read_lowercase: preserves multiline content" {
    printf "Line ONE\nLine TWO\n" > "$BATS_TEST_DIR/multi.txt"
    result=$(read_lowercase "$BATS_TEST_DIR/multi.txt")
    [[ "$result" == *"line one"* ]]
    [[ "$result" == *"line two"* ]]
}
