---
description: "Explain Super-Ralph plugin and available commands"
---

# Super-Ralph Plugin Help

Please explain the following to the user:

## What is Super-Ralph?

Super-Ralph combines two proven systems into one plugin:

- **Ralph Loop** — An iterative development loop where Claude works on the same task repeatedly, seeing its previous work in files and git history, until completion.
- **Super-Ralph Methodology** — 14 disciplined engineering skills (sr-brainstorming, sr-test-driven-development, sr-systematic-debugging, sr-requesting-code-review, sr-verification-before-completion) that prevent ad-hoc implementation.

**Result:** An autonomous AI agent with both endurance (runs for hours) and discipline (follows engineering best practices).

## Available Commands

### /sr-ralph-loop \<PROMPT\> [OPTIONS]

Start a Super-Ralph loop in your current session.

**Usage:**
```
/sr-ralph-loop "Refactor the cache layer" --max-iterations 20
/sr-ralph-loop "Add tests" --completion-promise "TESTS COMPLETE"
```

**Options:**
- `--max-iterations <n>` - Max iterations before auto-stop
- `--completion-promise <text>` - Promise phrase to signal completion

**How it works:**
1. Creates `.claude/super-ralph-loop.local.md` state file
2. You work on the task using sr- skills
3. When you try to exit, stop hook intercepts
4. Same prompt fed back
5. You see your previous work
6. Continues until promise detected or max iterations

---

### /sr-cancel-ralph

Cancel an active Super-Ralph loop (removes the loop state file).

---

## Skills (14 total)

All skills use the `sr-` prefix to avoid conflicts with other plugins:

| Skill | When to Use |
|-------|-------------|
| `/using-super-ralph` | Every conversation — master orchestrator |
| `/sr-brainstorming` | Before any new feature or creative work |
| `/sr-writing-plans` | Creating implementation plans from designs |
| `/sr-test-driven-development` | All implementation work (RED-GREEN-REFACTOR) |
| `/sr-systematic-debugging` | Any bug, test failure, or unexpected behavior |
| `/sr-verification-before-completion` | Before claiming work is done |
| `/sr-subagent-driven-development` | Dispatching subagents for independent tasks |
| `/sr-executing-plans` | Running plans in batches with checkpoints |
| `/sr-requesting-code-review` | Dispatching code-reviewer subagent |
| `/sr-receiving-code-review` | Evaluating review feedback critically |
| `/sr-finishing-a-development-branch` | Merging, PR, or cleanup after completion |
| `/sr-using-git-worktrees` | Isolated workspaces for feature development |
| `/sr-dispatching-parallel-agents` | Parallel agents for independent problems |
| `/sr-writing-skills` | Creating or editing skills (TDD for docs) |

## Completion Promises

To signal completion, Claude must output a `<promise>` tag:

```
<promise>TASK COMPLETE</promise>
```

The stop hook looks for this specific tag. Without it (or `--max-iterations`), Ralph runs infinitely.

## Example

```
/sr-ralph-loop "Build a REST API for todos with full test coverage" --completion-promise "API COMPLETE" --max-iterations 15
```

Super-Ralph will:
1. Brainstorm the API design (sr-brainstorming)
2. Write an implementation plan (sr-writing-plans)
3. Implement with strict TDD (sr-test-driven-development)
4. Debug any failures (sr-systematic-debugging)
5. Verify everything passes (sr-verification-before-completion)
6. Output `<promise>API COMPLETE</promise>` when truly done

## Note

Super-Ralph includes all skills from the [Superpowers](https://github.com/obra/superpowers) plugin. If you have Superpowers installed separately, you can uninstall it to avoid duplicate skill names.
