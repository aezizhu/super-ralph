# Ralph Skill Hooks

Decision table for which super-ralph skill to invoke based on Ralph loop state.

## Task Classification Hook

Run this at the START of every Ralph loop iteration before any implementation work.

```
INPUT: Current task from .ralph/fix_plan.md
OUTPUT: Skill to invoke

CLASSIFY:
  IF task contains "add", "create", "implement", "build", "new"
    AND no design document exists in docs/plans/ for this feature
    → INVOKE: sr-brainstorming
    → THEN: sr-writing-plans
    → THEN: sr-using-git-worktrees

  IF task contains "fix", "bug", "error", "broken", "failing", "crash"
    → INVOKE: sr-systematic-debugging

  IF task references a plan document in docs/plans/
    OR task is a sub-task from an existing plan
    → INVOKE: sr-test-driven-development
    → WITH: sr-subagent-driven-development (if multiple independent tasks)

  IF all tasks in fix_plan.md are marked [x]
    → INVOKE: sr-verification-before-completion
    → THEN: sr-finishing-a-development-branch

  IF task contains "review", "feedback", "PR comments"
    → INVOKE: sr-receiving-code-review

  DEFAULT:
    → INVOKE: sr-test-driven-development
```

## Between-Task Hook

Run AFTER completing each task and BEFORE starting the next.

```
AFTER task completion:
  1. INVOKE: sr-requesting-code-review (spec compliance check)
  2. IF issues found:
     → Fix issues
     → Re-review
  3. INVOKE: sr-verification-before-completion (for the completed task)
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
  → INVOKE: sr-dispatching-parallel-agents
  → Each agent follows sr-test-driven-development
  → Review all results before committing
```

## Error Recovery Hook

When a loop iteration encounters failures:

```
IF test failure:
  → INVOKE: sr-systematic-debugging
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
