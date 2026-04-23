#!/bin/bash
# super-ralph-stats - Metrics analytics for Super-Ralph loop execution
# Adapted from upstream ralph-stats.sh (commit dc89f16).
# Reads .ralph/logs/metrics.jsonl and prints a JSON summary.

set -e

SUPER_RALPH_DIR="${SUPER_RALPH_DIR:-.ralph}"
METRICS_FILE="$SUPER_RALPH_DIR/logs/metrics.jsonl"

if [[ ! -f "$METRICS_FILE" ]]; then
    echo '{"error":"No metrics file found. Run super-ralph first to generate metrics."}' >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo '{"error":"jq is required for super-ralph-stats"}' >&2
    exit 1
fi

jq -s '{
    total_loops: length,
    successful: (map(select(.success==true)) | length),
    avg_duration: (if length > 0 then (map(.duration) | add) / length else 0 end),
    total_calls: (map(.calls) | add // 0)
}' "$METRICS_FILE"
