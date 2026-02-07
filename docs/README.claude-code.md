# Super-Ralph for Claude Code

## Quick Install (Plugin)

In Claude Code, run:

```
/plugin add https://github.com/aezizhu/super-ralph
```

Select **super-ralph** from the plugin list to install. Restart Claude Code for skills to take effect.

> **Note:** Super-Ralph includes all skills from the Superpowers plugin. You can uninstall Superpowers after installing Super-Ralph.

## What You Get

**3 commands** (Ralph Loop):
- `/sr-ralph-loop` — Start an autonomous development loop
- `/sr-cancel-ralph` — Cancel an active loop
- `/sr-help` — Show all commands and skills

**14 skills** (Superpowers Methodology):

| Skill | Trigger |
|-------|---------|
| using-super-ralph | Every conversation (master orchestrator) |
| sr-brainstorming | New features, creative work, design decisions |
| sr-writing-plans | Approved design ready for implementation breakdown |
| sr-test-driven-development | Any implementation (features, bugs, refactoring) |
| sr-systematic-debugging | Any technical issue (test failures, bugs, errors) |
| sr-verification-before-completion | Before any completion claim or commit |
| sr-subagent-driven-development | Executing plan with independent tasks |
| sr-executing-plans | Batch execution with human checkpoints |
| sr-requesting-code-review | After tasks, before merge |
| sr-receiving-code-review | When receiving review feedback |
| sr-finishing-a-development-branch | All tasks complete, ready to integrate |
| sr-dispatching-parallel-agents | 3+ independent failures |
| sr-using-git-worktrees | Feature isolation |
| sr-writing-skills | Creating/editing skills |

## How It Works

When you describe a task, Claude Code automatically matches it to the relevant skill:
- "Build a feature" → sr-brainstorming → sr-writing-plans → sr-test-driven-development
- "Fix this bug" → sr-systematic-debugging → sr-test-driven-development
- "Is this done?" → sr-verification-before-completion

For autonomous loops, use `/sr-ralph-loop`:
```
/sr-ralph-loop "Build a todo API" --completion-promise "DONE" --max-iterations 15
```

## Updating

```
/plugin update super-ralph
```

## Uninstalling

Use `/plugin` to browse installed plugins and remove Super-Ralph.
