#!/usr/bin/env bash

# file_protection.sh - File integrity validation for Super-Ralph projects
# Validates that critical .ralph/ configuration files exist before loop
# execution. Adapted from upstream ralph-claude-code lib/file_protection.sh
# (commits 5ae0d21, 7c01c73). Super-Ralph-specific adaptations:
#   - RALPH_REQUIRED_PATHS reflects Super-Ralph's file layout.
#   - Recovery hint points at super-ralph-setup rather than ralph-enable,
#     which Super-Ralph does not ship.

# Required paths for a functioning Super-Ralph project.
# Includes only files critical for the loop to run — not optional state files.
RALPH_REQUIRED_PATHS=(
    ".ralph"
    ".ralph/PROMPT.md"
    ".ralph/fix_plan.md"
    ".ralph/AGENT.md"
    ".ralphrc"
)

# Populated by validate_ralph_integrity with the list of missing paths.
RALPH_MISSING_FILES=()

# Validate that all required paths exist.
# Sets RALPH_MISSING_FILES with any missing entries.
# Returns 0 when intact, 1 when anything is missing.
validate_ralph_integrity() {
    local path
    RALPH_MISSING_FILES=()

    for path in "${RALPH_REQUIRED_PATHS[@]}"; do
        if [[ ! -e "$path" ]]; then
            RALPH_MISSING_FILES+=("$path")
        fi
    done

    if [[ ${#RALPH_MISSING_FILES[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Generate a human-readable integrity report.
# Must be called after validate_ralph_integrity.
get_integrity_report() {
    if [[ ${#RALPH_MISSING_FILES[@]} -eq 0 ]]; then
        echo "All required Super-Ralph files are intact."
        return 0
    fi

    echo "Super-Ralph integrity check failed. Missing files:"
    local path
    for path in "${RALPH_MISSING_FILES[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "To restore, run 'super-ralph-setup <project>' in a scratch directory"
    echo "and copy the generated .ralph/ back into this project."
    return 0
}

export -f validate_ralph_integrity
export -f get_integrity_report
