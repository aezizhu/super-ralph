#!/usr/bin/env bash

# tdd_gate.sh - TDD Enforcement Gate for Super-Ralph
# Validates that test-driven development practices are being followed
# by analyzing Claude's output for TDD compliance signals

SUPER_RALPH_DIR="${SUPER_RALPH_DIR:-.ralph}"

# Source shared utilities
GATE_UTILS_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=gate_utils.sh
source "$GATE_UTILS_DIR/gate_utils.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# TDD compliance patterns
TDD_RED_PATTERNS=(
    "writ(e|ing).*failing.*test"
    "writ(e|ing).*test.*first"
    "\\bRED\\b.*phase"
    "\\btest(s)?\\b.*(should |must |will )?fail"
    "expected.*to fail"
    "watch.*(it |the test )?fail"
    "expect(ed)? (it |the test )?to fail"
)

TDD_GREEN_PATTERNS=(
    "\\bGREEN\\b.*phase"
    "minimal.*code.*(to )?pass"
    "make.*test(s)?.*pass"
    "\\btest(s)?\\b.*(now )?(pass|passing|passed)"
    "all.*tests?.*(pass|passing|passed|green)"
)

TDD_VIOLATION_PATTERNS=(
    "implement.*first.*then.*test"
    "skip(ping)?.*test"
    "test(ing)?.*later"
    "manual(ly)?.*test.*only"
    "no.*test(s|ing)?.*needed"
    "too.*simple.*(to |for ).*test"
    "don.t need.*(a |any )?test"
    "without.*(writing )?tests?"
)

# Check if Claude's output shows TDD compliance
# Returns 0 if compliant, 1 if violations detected
check_tdd_compliance() {
    local output_file="$1"

    local output_lower
    output_lower=$(read_lowercase "$output_file") || return 0

    local violations
    violations=$(count_pattern_matches "$output_lower" "${TDD_VIOLATION_PATTERNS[@]}")

    if [[ $violations -gt 0 ]]; then
        return 1
    fi

    return 0
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
    output_lower=$(read_lowercase "$output_file") || {
        echo '{"compliant": true, "violations": 0, "red_indicators": 0, "green_indicators": 0}' > "$result_file"
        return 0
    }

    local violations
    violations=$(count_pattern_matches "$output_lower" "${TDD_VIOLATION_PATTERNS[@]}")
    local red_indicators
    red_indicators=$(count_pattern_matches "$output_lower" "${TDD_RED_PATTERNS[@]}")
    local green_indicators
    green_indicators=$(count_pattern_matches "$output_lower" "${TDD_GREEN_PATTERNS[@]}")
    local violation_details
    violation_details=$(collect_pattern_details "$output_lower" "${TDD_VIOLATION_PATTERNS[@]}")

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
