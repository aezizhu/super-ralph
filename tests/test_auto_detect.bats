#!/usr/bin/env bats

# Tests for detect_project_tools in super_ralph_loop.sh

setup() {
    export TEST_PROJECT="$BATS_TMPDIR/auto_detect_test_$$"
    mkdir -p "$TEST_PROJECT"
    cd "$TEST_PROJECT"

    # Source just the detection function from the main script
    # We need to extract it since the main script has set -e and other side effects
    eval "$(sed -n '/^detect_project_tools/,/^}/p' "$BATS_TEST_DIRNAME/../standalone/super_ralph_loop.sh")"
}

teardown() {
    cd /
    rm -rf "$TEST_PROJECT"
}

# ============================================================================
# Auto-detection tests
# ============================================================================

@test "detect_project_tools: always includes base tools" {
    result=$(detect_project_tools)
    [[ "$result" == *"Write,Read,Edit"* ]]
    [[ "$result" == *"Bash(git *)"* ]]
}

@test "detect_project_tools: detects Node.js project" {
    echo '{}' > package.json
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(npm *)"* ]]
    [[ "$result" == *"Bash(node *)"* ]]
}

@test "detect_project_tools: detects yarn project" {
    echo '{}' > package.json
    touch yarn.lock
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(yarn *)"* ]]
}

@test "detect_project_tools: detects pnpm project" {
    echo '{}' > package.json
    touch pnpm-lock.yaml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(pnpm *)"* ]]
}

@test "detect_project_tools: detects bun project" {
    echo '{}' > package.json
    touch bun.lockb
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(bun *)"* ]]
}

@test "detect_project_tools: detects Python project (pyproject.toml)" {
    touch pyproject.toml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(python *)"* ]]
    [[ "$result" == *"Bash(pytest *)"* ]]
}

@test "detect_project_tools: detects Python project (requirements.txt)" {
    touch requirements.txt
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(python *)"* ]]
    [[ "$result" == *"Bash(pip *)"* ]]
}

@test "detect_project_tools: detects Poetry project" {
    printf '[tool.poetry]\nname = "test"\n' > pyproject.toml
    touch poetry.lock
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(poetry *)"* ]]
}

@test "detect_project_tools: detects Pipenv project" {
    touch Pipfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(pipenv *)"* ]]
}

@test "detect_project_tools: detects Rust project" {
    touch Cargo.toml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(cargo *)"* ]]
}

@test "detect_project_tools: detects Go project" {
    touch go.mod
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(go *)"* ]]
}

@test "detect_project_tools: detects Maven project" {
    touch pom.xml
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(mvn *)"* ]]
    [[ "$result" == *"Bash(java *)"* ]]
}

@test "detect_project_tools: detects Gradle project" {
    touch build.gradle
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(gradle *)"* ]]
}

@test "detect_project_tools: detects Ruby project" {
    touch Gemfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(ruby *)"* ]]
    [[ "$result" == *"Bash(bundle *)"* ]]
}

@test "detect_project_tools: detects Docker project" {
    touch Dockerfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(docker *)"* ]]
}

@test "detect_project_tools: detects Makefile project" {
    touch Makefile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(make *)"* ]]
}

@test "detect_project_tools: always includes bats" {
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(bats *)"* ]]
}

@test "detect_project_tools: detects multi-language project" {
    echo '{}' > package.json
    touch Cargo.toml
    touch Dockerfile
    result=$(detect_project_tools)
    [[ "$result" == *"Bash(npm *)"* ]]
    [[ "$result" == *"Bash(cargo *)"* ]]
    [[ "$result" == *"Bash(docker *)"* ]]
}

@test "detect_project_tools: empty project gets base tools only" {
    result=$(detect_project_tools)
    # Should have base tools + bats
    [[ "$result" == *"Write,Read,Edit"* ]]
    # Should NOT have language-specific tools
    [[ "$result" != *"Bash(npm *)"* ]]
    [[ "$result" != *"Bash(cargo *)"* ]]
    [[ "$result" != *"Bash(python *)"* ]]
}
