#!/usr/bin/env bash

# verification_gate.sh - Verification Before Completion Gate for Super-Ralph
# Ensures no completion claims are made without fresh verification evidence

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

# Patterns that indicate unverified completion claims
UNVERIFIED_CLAIM_PATTERNS=(
    "should (now )?pass"
    "should (now )?work"
    "probably works"
    "looks correct"
    "seems to (be )?(work|correct|fixed|done)"
    "i think it.s (done|complete|fixed|working)"
    "i.m (fairly |pretty |quite )?confident"
    "just this once"
    "linter passed.*build"
    "tests? should"
    "i believe (it|this|the).*(work|pass|correct)"
    "that should (do|fix|resolve|handle)"
)

# Patterns that indicate verified completion claims (evidence-based)
VERIFIED_CLAIM_PATTERNS=(
    "[0-9]+ (tests? )?(pass|passed|passing)"
    "exit code[: ]*0"
    "0 (failures|errors|failed)"
    "all [0-9]+ tests? (pass|passed|passing)"
    "build.*success(ful|fully)?"
    "build.*(exit[: ]*0|succeeded)"
    "linter.*0 (errors|warnings|issues)"
    "tests?.*(pass|passed|passing).*[0-9]+"
    "[0-9]+ (of [0-9]+ )?(tests? )?(pass|passed|passing)"
    "\\bok\\b.*[0-9]+ tests?"
    "ran [0-9]+ tests?"
)

# Check if completion claims are backed by verification evidence
# Returns 0 if verified, 1 if unverified claims detected
check_verification() {
    local output_file="$1"

    local output_lower
    output_lower=$(read_lowercase "$output_file") || return 0

    local unverified_count
    unverified_count=$(count_pattern_matches "$output_lower" "${UNVERIFIED_CLAIM_PATTERNS[@]}")
    local verified_count
    verified_count=$(count_pattern_matches "$output_lower" "${VERIFIED_CLAIM_PATTERNS[@]}")

    if [[ $unverified_count -gt 0 ]] && [[ $verified_count -eq 0 ]]; then
        return 1
    fi

    return 0
}

# Analyze verification compliance from Claude's output
analyze_verification_status() {
    local output_file="$1"
    local result_file="${2:-$SUPER_RALPH_DIR/.verification_status}"

    if [[ ! -f "$output_file" ]]; then
        echo '{"verified": true, "unverified_claims": 0, "evidence_found": 0}' > "$result_file"
        return 0
    fi

    local output_lower
    output_lower=$(read_lowercase "$output_file") || {
        echo '{"verified": true, "unverified_claims": 0, "evidence_found": 0}' > "$result_file"
        return 0
    }

    local unverified_claims
    unverified_claims=$(count_pattern_matches "$output_lower" "${UNVERIFIED_CLAIM_PATTERNS[@]}")
    local evidence_found
    evidence_found=$(count_pattern_matches "$output_lower" "${VERIFIED_CLAIM_PATTERNS[@]}")
    local claim_details
    claim_details=$(collect_pattern_details "$output_lower" "${UNVERIFIED_CLAIM_PATTERNS[@]}")

    local verified="true"
    if [[ $unverified_claims -gt 0 ]] && [[ $evidence_found -eq 0 ]]; then
        verified="false"
    fi

    jq -n \
        --argjson verified "$verified" \
        --argjson unverified_claims "$unverified_claims" \
        --argjson evidence_found "$evidence_found" \
        --argjson claim_details "$claim_details" \
        '{
            verified: $verified,
            unverified_claims: $unverified_claims,
            evidence_found: $evidence_found,
            claim_details: $claim_details
        }' > "$result_file"

    return 0
}

# Log verification gate summary
log_verification_summary() {
    local verification_file="${1:-$SUPER_RALPH_DIR/.verification_status}"

    if [[ ! -f "$verification_file" ]]; then
        return 0
    fi

    local verified
    verified=$(jq -r '.verified' "$verification_file" 2>/dev/null)
    local unverified_claims
    unverified_claims=$(jq -r '.unverified_claims' "$verification_file" 2>/dev/null)
    local evidence_found
    evidence_found=$(jq -r '.evidence_found' "$verification_file" 2>/dev/null)

    if [[ "$verified" == "true" ]]; then
        echo -e "${GREEN}Verification Gate: PASS${NC} ($evidence_found evidence point(s) found)" >&2
    else
        echo -e "${RED}Verification Gate: WARNING${NC} ($unverified_claims unverified claim(s), $evidence_found evidence)" >&2
        echo -e "${YELLOW}Completion claims detected without verification evidence.${NC}" >&2
    fi
}

# Get verification enforcement context for the prompt
get_verification_enforcement_context() {
    echo "MANDATORY: NO completion claims without verification. Run test command, read output, THEN claim results. 'Should pass' = not verified."
}

# Check if the RALPH_STATUS EXIT_SIGNAL is backed by verification
# This is the final gate before allowing exit
validate_exit_signal() {
    local analysis_file="${1:-$SUPER_RALPH_DIR/.response_analysis}"

    if [[ ! -f "$analysis_file" ]]; then
        echo "false"
        return 1
    fi

    local exit_signal
    exit_signal=$(jq -r '.analysis.exit_signal // false' "$analysis_file" 2>/dev/null)

    if [[ "$exit_signal" != "true" ]]; then
        echo "false"
        return 1
    fi

    # EXIT_SIGNAL is true - verify that tests were actually run
    local output_file
    output_file=$(jq -r '.output_file // ""' "$analysis_file" 2>/dev/null)

    if [[ -n "$output_file" ]] && [[ -f "$output_file" ]]; then
        if check_verification "$output_file"; then
            echo "true"
            return 0
        else
            echo "false"
            return 1
        fi
    fi

    # If we can't find the output file, trust the signal
    echo "true"
    return 0
}

# Export functions
export -f check_verification
export -f analyze_verification_status
export -f log_verification_summary
export -f get_verification_enforcement_context
export -f validate_exit_signal
