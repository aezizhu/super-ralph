#!/usr/bin/env bash

# tdd_gate.sh - TDD Enforcement Gate for Super-Ralph
# Validates that test-driven development practices are being followed
# by analyzing Claude's output for TDD compliance signals

SUPER_RALPH_DIR="${SUPER_RALPH_DIR:-.ralph}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# TDD compliance patterns
TDD_RED_PATTERNS=(
    "write.*failing.*test"
    "write.*test.*first"
    "RED.*phase"
    "test.*fail"
    "expected.*fail"
    "watch.*fail"
)

TDD_GREEN_PATTERNS=(
    "GREEN.*phase"
    "minimal.*code.*pass"
    "make.*test.*pass"
    "test.*pass"
    "all.*tests.*pass"
)

TDD_VIOLATION_PATTERNS=(
    "implement.*first.*then.*test"
    "skip.*test"
    "test.*later"
    "manual.*test.*only"
    "no.*test.*needed"
    "too.*simple.*test"
)

# Check if Claude's output shows TDD compliance
# Returns 0 if compliant, 1 if violations detected
check_tdd_compliance() {
    local output_file="$1"

    if [[ ! -f "$output_file" ]]; then
        return 0  # No output to check
    fi

    local output_content
    output_content=$(cat "$output_file")
    local output_lower
    output_lower=$(echo "$output_content" | tr '[:upper:]' '[:lower:]')

    # Check for TDD violation patterns
    local violations=0
    for pattern in "${TDD_VIOLATION_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            violations=$((violations + 1))
        fi
    done

    # Check for RED phase indicators
    local red_indicators=0
    for pattern in "${TDD_RED_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            red_indicators=$((red_indicators + 1))
        fi
    done

    # Check for GREEN phase indicators
    local green_indicators=0
    for pattern in "${TDD_GREEN_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            green_indicators=$((green_indicators + 1))
        fi
    done

    # Determine compliance
    if [[ $violations -gt 0 ]]; then
        return 1  # Violations found
    fi

    return 0  # Compliant (or no clear signal either way)
}

# Analyze TDD compliance from the RALPH_STATUS block
# Returns structured compliance data
analyze_tdd_status() {
    local output_file="$1"
    local result_file="${2:-$SUPER_RALPH_DIR/.tdd_compliance}"

    if [[ ! -f "$output_file" ]]; then
        echo '{"compliant": true, "violations": 0, "red_indicators": 0, "green_indicators": 0}' > "$result_file"
        return 0
    fi

    local output_lower
    output_lower=$(cat "$output_file" | tr '[:upper:]' '[:lower:]')

    local violations=0
    local red_indicators=0
    local green_indicators=0
    local violation_details="[]"

    # Count violations
    for pattern in "${TDD_VIOLATION_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            violations=$((violations + 1))
            local match
            match=$(echo "$output_lower" | grep -oE "$pattern" | head -1)
            violation_details=$(echo "$violation_details" | jq ". += [\"$match\"]" 2>/dev/null || echo "$violation_details")
        fi
    done

    # Count RED indicators
    for pattern in "${TDD_RED_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            red_indicators=$((red_indicators + 1))
        fi
    done

    # Count GREEN indicators
    for pattern in "${TDD_GREEN_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            green_indicators=$((green_indicators + 1))
        fi
    done

    local compliant="true"
    if [[ $violations -gt 0 ]]; then
        compliant="false"
    fi

    jq -n \
        --argjson compliant "$compliant" \
        --argjson violations "$violations" \
        --argjson red_indicators "$red_indicators" \
        --argjson green_indicators "$green_indicators" \
        --argjson violation_details "$violation_details" \
        '{
            compliant: $compliant,
            violations: $violations,
            red_indicators: $red_indicators,
            green_indicators: $green_indicators,
            violation_details: $violation_details
        }' > "$result_file"

    return 0
}

# Log TDD compliance summary
log_tdd_summary() {
    local compliance_file="${1:-$SUPER_RALPH_DIR/.tdd_compliance}"

    if [[ ! -f "$compliance_file" ]]; then
        return 0
    fi

    local compliant
    compliant=$(jq -r '.compliant' "$compliance_file" 2>/dev/null)
    local violations
    violations=$(jq -r '.violations' "$compliance_file" 2>/dev/null)
    local red_indicators
    red_indicators=$(jq -r '.red_indicators' "$compliance_file" 2>/dev/null)
    local green_indicators
    green_indicators=$(jq -r '.green_indicators' "$compliance_file" 2>/dev/null)

    if [[ "$compliant" == "true" ]]; then
        echo -e "${GREEN}TDD Gate: PASS${NC} (RED: $red_indicators, GREEN: $green_indicators)" >&2
    else
        echo -e "${RED}TDD Gate: VIOLATION${NC} ($violations violation(s) detected)" >&2
        echo -e "${YELLOW}TDD violations found in output. Consider enforcing stricter TDD.${NC}" >&2
    fi
}

# Get the TDD enforcement instruction to inject into the prompt
get_tdd_enforcement_context() {
    echo "MANDATORY: Follow TDD strictly. Write failing test FIRST, verify it fails, then write minimal code to pass. Code before test = delete and restart."
}

# Export functions
export -f check_tdd_compliance
export -f analyze_tdd_status
export -f log_tdd_summary
export -f get_tdd_enforcement_context
