# Ralph Skill Hooks

Decision table for which superpowers skill to invoke based on Ralph loop state.

## Task Classification Hook

Run this at the START of every Ralph loop iteration before any implementation work.

```
INPUT: Current task from .ralph/fix_plan.md
OUTPUT: Skill to invoke

CLASSIFY:
  IF task contains "add", "create", "implement", "build", "new"
    AND no design document exists in docs/plans/ for this feature
    → INVOKE: brainstorming
    → THEN: writing-plans
    → THEN: using-git-worktrees

  IF task contains "fix", "bug", "error", "broken", "failing", "crash"
    → INVOKE: systematic-debugging

  IF task references a plan document in docs/plans/
    OR task is a sub-task from an existing plan
    → INVOKE: test-driven-development
    → WITH: subagent-driven-development (if multiple independent tasks)

  IF all tasks in fix_plan.md are marked [x]
    → INVOKE: verification-before-completion
    → THEN: finishing-a-development-branch

  IF task contains "review", "feedback", "PR comments"
    → INVOKE: receiving-code-review

  DEFAULT:
    → INVOKE: test-driven-development
```

## Between-Task Hook

Run AFTER completing each task and BEFORE starting the next.

```
AFTER task completion:
  1. INVOKE: requesting-code-review (spec compliance check)
  2. IF issues found:
     → Fix issues
     → Re-review
  3. INVOKE: verification-before-completion (for the completed task)
  4. Commit with conventional message
  5. Update .ralph/fix_plan.md: mark task [x]
```

## Loop-End Hook

Run at the END of every Ralph loop iteration, before writing RALPH_STATUS.

```
BEFORE writing RALPH_STATUS:
  1. Run test suite command
  2. Read output (do NOT assume)
  3. Set TESTS_STATUS based on actual output
  4. Set METHODOLOGY to the primary workflow used this loop
  5. Set SKILL_USED to the most significant skill invoked
  6. IF all fix_plan.md items [x] AND tests pass AND specs verified:
     → EXIT_SIGNAL: true
  7. ELSE:
     → EXIT_SIGNAL: false
```

## Parallel Task Hook

When fix_plan.md has multiple independent tasks at the same priority level:

```
IF 2+ tasks are independent (different files, different subsystems):
  → INVOKE: dispatching-parallel-agents
  → Each agent follows test-driven-development
  → Review all results before committing
```

## Error Recovery Hook

When a loop iteration encounters failures:

```
IF test failure:
  → INVOKE: systematic-debugging
  → Root cause investigation before any fix attempt

IF 3+ consecutive failures on same issue:
  → Set STATUS: BLOCKED
  → RECOMMENDATION: "Need human help - [specific issue]"
  → Do NOT attempt another fix

IF circuit breaker opens:
  → Respect the halt
  → Set EXIT_SIGNAL: false
  → Wait for human intervention or ralph --reset-circuit
```
