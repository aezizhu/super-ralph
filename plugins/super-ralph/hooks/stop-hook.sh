#!/bin/bash

# Ralph Loop Stop Hook
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

# No `set -e` — we handle errors explicitly to avoid silent crashes
# that would let Claude exit the loop unexpectedly
set -u

# Debug logging (enable with SUPER_RALPH_DEBUG=1)
DEBUG_LOG=".claude/super-ralph-debug.log"
debug() {
  if [[ "${SUPER_RALPH_DEBUG:-0}" == "1" ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$DEBUG_LOG" 2>/dev/null
  fi
}

debug "=== Stop hook fired ==="

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)
debug "Hook input length: ${#HOOK_INPUT}"

# Check if ralph-loop is active
RALPH_STATE_FILE=".claude/super-ralph-loop.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  # No active loop - allow exit
  debug "No state file found at $RALPH_STATE_FILE — allowing exit"
  exit 0
fi

debug "State file found: $RALPH_STATE_FILE"

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE") || true

if [[ -z "$FRONTMATTER" ]]; then
  echo "⚠️  Super-Ralph loop: State file has no frontmatter" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Expected YAML between --- delimiters" >&2
  echo "   Super-Ralph loop is stopping. Run /using-super-ralph again to start fresh." >&2
  debug "ERROR: empty frontmatter from state file"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || true)
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || true)
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || true)

debug "Parsed: iteration=$ITERATION max=$MAX_ITERATIONS promise=$COMPLETION_PROMISE"

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Super-Ralph loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Super-Ralph loop is stopping. Run /using-super-ralph again to start fresh." >&2
  debug "ERROR: iteration field invalid: '$ITERATION'"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Super-Ralph loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Super-Ralph loop is stopping. Run /using-super-ralph again to start fresh." >&2
  debug "ERROR: max_iterations field invalid: '$MAX_ITERATIONS'"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Super-Ralph loop: Max iterations ($MAX_ITERATIONS) reached."
  debug "Max iterations reached ($ITERATION >= $MAX_ITERATIONS)"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path' 2>/dev/null) || true

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ "$TRANSCRIPT_PATH" == "null" ]]; then
  echo "⚠️  Super-Ralph loop: No transcript_path in hook input" >&2
  echo "   This may indicate a Claude Code version incompatibility." >&2
  echo "   Super-Ralph loop is stopping." >&2
  debug "ERROR: transcript_path missing or null from hook input"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Super-Ralph loop: Transcript file not found" >&2
  echo "   Expected: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a Claude Code internal issue." >&2
  echo "   Super-Ralph loop is stopping." >&2
  debug "ERROR: transcript file not found: $TRANSCRIPT_PATH"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

debug "Transcript: $TRANSCRIPT_PATH"

# Session isolation: ensure this loop belongs to the current session.
# Each Claude Code session has a unique transcript path. We store it on first
# hook invocation. If a different session encounters a stale state file, we
# clean it up and allow exit instead of trapping an unrelated session.
STORED_SESSION=$(echo "$FRONTMATTER" | grep '^session_transcript:' | sed 's/session_transcript: *//' | sed 's/^"\(.*\)"$/\1/' || true)

if [[ -z "$STORED_SESSION" ]]; then
  # No session_transcript yet — the loop was just created but the hook hasn't
  # claimed it. Check if this is OUR loop (recent) or a stale orphan (old).
  # `find -mmin +5` matches files modified more than 5 minutes ago (works on macOS + Linux).
  if [[ -n $(find "$RALPH_STATE_FILE" -mmin +5 2>/dev/null) ]]; then
    # State file is old and unclaimed — stale from a crashed session
    debug "Stale unclaimed state file (>5 min old) — cleaning up"
    echo "⚠️  Super-Ralph loop: Stale unclaimed state file from a crashed session." >&2
    echo "   Cleaning up and allowing exit." >&2
    rm -f "$RALPH_STATE_FILE"
    exit 0
  fi
  # Recent file — claim ownership for this session
  debug "Recording session ownership: $TRANSCRIPT_PATH"
  sed -i.bak "s|^active: true|active: true\nsession_transcript: \"$TRANSCRIPT_PATH\"|" "$RALPH_STATE_FILE"
  rm -f "${RALPH_STATE_FILE}.bak"
elif [[ "$STORED_SESSION" != "$TRANSCRIPT_PATH" ]]; then
  # Different session owns this loop — DO NOT delete their state file.
  # Just allow this session to exit without interfering.
  debug "Session mismatch: stored=$STORED_SESSION current=$TRANSCRIPT_PATH — not our loop, allowing exit"
  exit 0
fi

debug "Session ownership verified"

# Read last assistant message from transcript (JSONL format - one JSON per line)
# First check if there are any assistant messages
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Super-Ralph loop: No assistant messages found in transcript" >&2
  echo "   Transcript: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a transcript format issue" >&2
  echo "   Super-Ralph loop is stopping." >&2
  debug "ERROR: no assistant messages in transcript"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Extract last assistant message with explicit error handling
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1) || true
if [[ -z "$LAST_LINE" ]]; then
  echo "⚠️  Super-Ralph loop: Failed to extract last assistant message" >&2
  echo "   Super-Ralph loop is stopping." >&2
  debug "ERROR: failed to extract last assistant line"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Parse JSON with error handling — use || true to prevent crash
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null) || true

if [[ -z "$LAST_OUTPUT" ]]; then
  # Try to diagnose what went wrong with jq parsing
  local_jq_error=$(echo "$LAST_LINE" | jq -r '.message.content' 2>&1 >/dev/null) || true
  debug "ERROR: empty text content from jq parse. jq diagnostic: $local_jq_error"
  debug "ERROR: LAST_LINE first 200 chars: ${LAST_LINE:0:200}"
  echo "⚠️  Super-Ralph loop: Assistant message contained no text content" >&2
  echo "   This may indicate a transcript format change in Claude Code." >&2
  echo "   Super-Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

debug "Parsed assistant output (${#LAST_OUTPUT} chars)"

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags
  # Try perl first (multiline support), fall back to bash (single-line)
  PROMISE_TEXT=""
  if command -v perl &>/dev/null; then
    # -0777 slurps entire input, s flag makes . match newlines
    # .*? is non-greedy (takes FIRST tag), whitespace normalized
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  else
    # Pure bash fallback: extract single-line <promise> tags
    if [[ "$LAST_OUTPUT" =~ \<promise\>(.*)\</promise\> ]]; then
      PROMISE_TEXT="${BASH_REMATCH[1]}"
      # Trim whitespace
      PROMISE_TEXT="${PROMISE_TEXT#"${PROMISE_TEXT%%[![:space:]]*}"}"
      PROMISE_TEXT="${PROMISE_TEXT%"${PROMISE_TEXT##*[![:space:]]}"}"
    fi
    debug "Using bash fallback for promise extraction (perl not available)"
  fi

  # Use = for literal string comparison (not pattern matching)
  # == in [[ ]] does glob pattern matching which breaks with *, ?, [ characters
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Super-Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    debug "Completion promise matched — stopping loop"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
# Skip first --- line, skip until second --- line, then print everything after
# Use i>=2 instead of i==2 to handle --- in prompt content
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE") || true

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Super-Ralph loop: State file corrupted or incomplete" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: No prompt text found" >&2
  echo "" >&2
  echo "   This usually means:" >&2
  echo "     • State file was manually edited" >&2
  echo "     • File was corrupted during writing" >&2
  echo "" >&2
  echo "   Super-Ralph loop is stopping. Run /using-super-ralph again to start fresh." >&2
  debug "ERROR: no prompt text in state file"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (portable across macOS and Linux)
# sed -i.bak works on both macOS and Linux; remove backup after
debug "Updating iteration: $ITERATION -> $NEXT_ITERATION (CWD: $(pwd))"
if ! sed -i.bak "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE"; then
  echo "⚠️  Super-Ralph loop: Failed to update iteration counter" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   This may indicate a filesystem permission issue." >&2
  echo "   Super-Ralph loop is stopping." >&2
  debug "ERROR: sed failed to update iteration"
  rm -f "${RALPH_STATE_FILE}.bak"
  rm "$RALPH_STATE_FILE"
  exit 0
fi
rm -f "${RALPH_STATE_FILE}.bak"

# Verify the update succeeded
UPDATED_ITERATION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE" | grep '^iteration:' | sed 's/iteration: *//' || true)
if [[ "$UPDATED_ITERATION" != "$NEXT_ITERATION" ]]; then
  debug "WARNING: iteration update verification failed (expected $NEXT_ITERATION, got $UPDATED_ITERATION)"
fi
debug "State file after update: $(head -6 "$RALPH_STATE_FILE" 2>/dev/null)"

# Build system message with iteration count, completion info, AND methodology enforcement
# This is critical — without the methodology context, subsequent iterations lose the
# Super-Ralph skill enforcement that was present in the original /using-super-ralph command.
METHODOLOGY_CONTEXT="

Super-Ralph iteration $NEXT_ITERATION. FIRST: invoke /using-super-ralph to reload methodology.

SKILL ROUTING (use sr- prefix only, never superpowers:*):
feature→sr-brainstorming | plan→sr-writing-plans | code→sr-test-driven-development
bug→sr-systematic-debugging | done→sr-verification-before-completion
parallel→sr-subagent-driven-development | review→sr-requesting-code-review
all-complete→sr-finishing-a-development-branch

RULES: Announce skills before use. Evidence before assertions. One fix at a time. Never claim success without command output proof."

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Super-Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when statement is TRUE - do not lie to exit!)${METHODOLOGY_CONTEXT}"
else
  SYSTEM_MSG="🔄 Super-Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely${METHODOLOGY_CONTEXT}"
fi

debug "Blocking exit — iteration $NEXT_ITERATION"

# Output JSON to block the stop and feed prompt back
# The "reason" field contains the prompt that will be sent back to Claude
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0
