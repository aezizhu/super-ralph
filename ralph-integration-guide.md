# Super-Ralph Integration Guide

## How Ralph and Superpowers Connect

Ralph and Superpowers operate at different layers. Understanding this separation is key to integrating them.

### Layer Model

```
┌─────────────────────────────────────────────┐
│  Layer 3: METHODOLOGY (Super-Ralph)         │
│  - Brainstorming, TDD, debugging workflows  │
│  - Code review, verification                │
│  - Skill selection and enforcement          │
├─────────────────────────────────────────────┤
│  Layer 2: PROMPT (PROMPT.md / fix_plan.md)  │
│  - What to build, task priorities            │
│  - Status reporting (RALPH_STATUS)          │
│  - Exit signal management                   │
├─────────────────────────────────────────────┤
│  Layer 1: INFRASTRUCTURE (ralph_loop.sh)    │
│  - Loop execution, rate limiting            │
│  - Circuit breaker, session continuity      │
│  - Exit detection, monitoring               │
└─────────────────────────────────────────────┘
```

Super-Ralph operates entirely at Layer 3. It does not modify Layer 1 (Ralph's bash scripts) or Layer 2's structure (same RALPH_STATUS format, same fix_plan.md). It changes the **behavior inside each loop iteration** by enforcing superpowers workflows.

## Setup Options

### Option 1: Replace PROMPT.md (Recommended for New Projects)

```bash
ralph-setup my-project
cd my-project
cp /path/to/skills/super-ralph/super-ralph-prompt.md .ralph/PROMPT.md
ralph --monitor
```

### Option 2: Augment Existing PROMPT.md (For Active Projects)

Add the following section to your existing `.ralph/PROMPT.md` after the "Current Objectives" section:

```markdown
## Superpowers Methodology (MANDATORY)

Before ANY implementation:
1. Classify task: feature / bug / plan-task / completion
2. Features: brainstorm -> plan -> TDD
3. Bugs: systematic debugging (root cause first)
4. All code: test first, watch fail, implement, verify
5. Completion: run tests, read output, verify against specs
6. Never claim done without verification evidence
```

### Option 3: CLAUDE.md Integration (For Claude Code Projects)

Add to your project's `CLAUDE.md`:

```markdown
## Development Methodology

This project uses Super-Ralph (superpowers-enhanced Ralph).
Before implementing any task from .ralph/fix_plan.md:

1. Read the super-ralph skill from skills/super-ralph/SKILL.md
2. Follow the workflow for the detected task type
3. TDD is mandatory: test first, watch fail, implement
4. Verify before claiming completion
```

## How Each Ralph Phase Maps to Superpowers

### Loop Start: Task Selection

**Ralph default:** Pick highest priority from fix_plan.md, start implementing.

**Super-Ralph:** Pick highest priority, CLASSIFY it, select the appropriate superpowers workflow before touching code.

### During Implementation

**Ralph default:** Implement, run tests (~20% effort), commit.

**Super-Ralph:**
- Write failing test first (RED)
- Verify it fails correctly
- Write minimal code (GREEN)
- Verify all tests pass
- Refactor if needed
- Commit with conventional message

### Bug Encounters

**Ralph default:** Try to fix it, run tests, move on.

**Super-Ralph:**
1. Root cause investigation (read errors, reproduce, trace)
2. Pattern analysis (find working examples, compare)
3. Hypothesis and testing (single variable, minimal change)
4. Implementation (failing test first, then fix)
5. After 3 failed attempts: STOP, report BLOCKED

### Completion Detection

**Ralph default:** Check fix_plan.md checkboxes, set EXIT_SIGNAL if all done.

**Super-Ralph:**
1. Run full test suite, read actual output
2. Compare specs/ line by line against implementation
3. Run linter/build
4. Self-review git diff
5. ONLY THEN set EXIT_SIGNAL: true

## Compatibility Notes

### RALPH_STATUS Block

Super-Ralph adds two optional fields to the standard block:
- `METHODOLOGY:` -- which superpowers workflow was followed
- `SKILL_USED:` -- which specific skill was invoked

Ralph's response_analyzer.sh will ignore these extra fields (it uses `jq` to extract specific known fields). No changes to ralph_loop.sh are needed.

### Circuit Breaker Interaction

Super-Ralph's systematic debugging naturally works with Ralph's circuit breaker:
- If debugging takes multiple loops, each loop shows FILES_MODIFIED > 0 (diagnostic instrumentation)
- The circuit breaker's no-progress detection counts file changes, so debugging work registers as progress
- If truly stuck after 3 fix attempts, Super-Ralph sets STATUS: BLOCKED, which the circuit breaker handles

### Session Continuity

Super-Ralph benefits from Ralph's `--continue` flag:
- Design documents written in loop N are available in loop N+1
- Implementation plans persist across loops
- TDD state (which tests exist, which pass) is visible via git

### Rate Limiting

No changes. Superpowers workflows may use slightly more tokens per loop (due to planning and review) but fewer total loops (due to better quality and fewer rework cycles).

## Troubleshooting

### "Ralph exits too early"
Super-Ralph adds more completion indicators (design docs, review reports). If Ralph's exit detection triggers on phrases like "design complete," the EXIT_SIGNAL: false will prevent premature exit (Ralph requires both conditions).

### "Ralph gets stuck in brainstorming"
If requirements in `.ralph/specs/` are ambiguous, Super-Ralph will set STATUS: BLOCKED. Update specs with clearer requirements and reset the circuit breaker: `ralph --reset-circuit`.

### "TDD slows down the loop"
TDD produces fewer bugs and less rework. The total loop count will typically be lower even though individual loops take longer. If loop timeout is an issue, increase it: `ralph --timeout 30`.

### "Subagent dispatch not available"
Subagent-driven development requires Claude Code's subagent capabilities. If not available, Super-Ralph falls back to sequential TDD execution (Phase C without subagent dispatch), which still enforces test-first methodology.
