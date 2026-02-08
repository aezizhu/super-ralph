#!/usr/bin/env bash

# gate_utils.sh - Shared utilities for gate enforcement libraries
# Provides common pattern matching and JSON building functions

# Count how many patterns from an array match in the given text
# Usage: count_pattern_matches "text" PATTERN_ARRAY[@]
# Returns: count via stdout
count_pattern_matches() {
    local text="$1"
    shift
    local -a patterns=("$@")
    local count=0

    for pattern in "${patterns[@]}"; do
        if echo "$text" | grep -qE "$pattern"; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

# Collect matching patterns into a JSON array
# Usage: collect_pattern_details "text" PATTERN_ARRAY[@]
# Returns: JSON array string via stdout
collect_pattern_details() {
    local text="$1"
    shift
    local -a patterns=("$@")
    local details="[]"

    for pattern in "${patterns[@]}"; do
        if echo "$text" | grep -qE "$pattern"; then
            local match
            match=$(echo "$text" | grep -oE "$pattern" | head -1)
            details=$(echo "$details" | jq --arg m "$match" '. += [$m]' 2>/dev/null || echo "$details")
        fi
    done

    echo "$details"
}

# Read a file and return its content in lowercase
# Usage: read_lowercase "filepath"
# Returns: lowercase content via stdout
read_lowercase() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    tr '[:upper:]' '[:lower:]' < "$file"
}

# Export functions
export -f count_pattern_matches
export -f collect_pattern_details
export -f read_lowercase
