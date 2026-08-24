---
name: sr-executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Intentional Divergences

Upstream Superpowers' `executing-plans` skill dropped its "execute a
batch of 3, report, continue" pattern in early March 2026 (commit
`3bdd66e`), based on regression data showing batch-and-stop added
~25 min of overhead without measurably improving plan quality. Their
replacement flow is "execute all tasks, report when complete."

Super-Ralph **deliberately preserves the 3-task batch pattern** here.
`sr-executing-plans` is the dedicated "parallel session with
human-checkpoint fallback" path offered in `sr-writing-plans`'s
Execution Handoff. Harnesses that don't have good subagent support
(e.g., bare terminals, plugin-less Gemini CLI, headless CI without
Task tool access) rely on this serialized, checkpoint-driven flow —
that's the UX contract we're preserving. Harnesses with good subagent
support should prefer `sr-subagent-driven-development` and get the
single-pass behavior Superpowers upstream adopted.

If you're extending this skill, keep the batch pattern intact. If you
want unbatched execution, use `sr-subagent-driven-development`.

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

**Core principle:** Batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the sr-executing-plans skill to implement this plan."

## The Process

### Step 1: Load and Review Plan
1. Ensure an isolated workspace: use sr-using-git-worktrees to create one or verify the existing one
2. Read plan file
3. Review critically - identify any questions or concerns about the plan
4. If concerns: Raise them with your human partner before starting
5. If no concerns: Create todo list and proceed

### Step 2: Execute Batch
**Default: First 3 tasks**

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Report
When batch complete:
- Show what was implemented
- Show verification output
- Say: "Ready for feedback."

### Step 4: Continue
Based on feedback:
- Apply changes if needed
- Execute next batch
- Repeat until complete

### Step 5: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the sr-finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use sr-finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Red Flags

Stop and reassess if you catch yourself:
- Skipping plan review and jumping straight to implementation
- Implementing more than 3 tasks without checking in for review
- Guessing when a plan step is unclear instead of asking
- Skipping verification commands specified in the plan
- Continuing after a verification failure instead of stopping
- Working on main/master branch without explicit consent

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Between batches: just report and wait
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Related Skills

- **sr-writing-plans**: Creates the plan this skill executes
- **sr-using-git-worktrees**: Set up isolated workspace before starting (required)
- **sr-finishing-a-development-branch**: Complete development after all tasks
- **sr-verification-before-completion**: Verify work before claiming batch complete
- **sr-test-driven-development**: TDD methodology for implementing each task
