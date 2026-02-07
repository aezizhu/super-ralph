# Super-Ralph for Codex

## Quick Install

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/aezizhu/super-ralph/refs/heads/main/.codex/INSTALL.md
```

## Manual Install

```bash
git clone https://github.com/aezizhu/super-ralph.git ~/.codex/super-ralph
mkdir -p ~/.agents/skills
ln -s ~/.codex/super-ralph/plugins/super-ralph/skills ~/.agents/skills/super-ralph
```

Restart Codex.

## How It Works

Codex discovers skills via `~/.agents/skills/`. The symlink points Codex to Super-Ralph's 14 skill directories. Each skill has a `SKILL.md` with YAML frontmatter (`name`, `description`) that Codex uses for auto-discovery.

When you describe a task, Codex automatically matches it to the relevant skill:
- "Build a feature" -> sr-brainstorming -> sr-writing-plans -> sr-test-driven-development
- "Fix this bug" -> sr-systematic-debugging -> sr-test-driven-development
- "Is this done?" -> sr-verification-before-completion

## Skills Included

| Skill | Trigger |
|-------|---------|
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
| using-super-ralph | Every conversation (master orchestrator) |
| sr-writing-skills | Creating/editing skills |

## Updating

```bash
cd ~/.codex/super-ralph && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/super-ralph
rm -rf ~/.codex/super-ralph
```
