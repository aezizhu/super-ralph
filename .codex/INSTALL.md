# Installing Super-Ralph for Codex

Enable Super-Ralph skills in Codex via native skill discovery. Just clone and symlink.

## Prerequisites

- Git

## Installation

1. **Clone the super-ralph repository:**
   ```bash
   git clone https://github.com/aezizhu/super-ralph.git ~/.codex/super-ralph
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/super-ralph/plugins/super-ralph/skills ~/.agents/skills/super-ralph
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\super-ralph" "$env:USERPROFILE\.codex\super-ralph\skills"
   ```

3. **Restart Codex** (quit and relaunch the CLI) to discover the skills.

## Verify

```bash
ls -la ~/.agents/skills/super-ralph
```

You should see a symlink pointing to your super-ralph skills directory containing 14 skill folders:
sr-brainstorming, sr-writing-plans, sr-test-driven-development, sr-systematic-debugging,
sr-verification-before-completion, sr-subagent-driven-development, sr-executing-plans,
sr-requesting-code-review, sr-receiving-code-review, sr-finishing-a-development-branch,
sr-dispatching-parallel-agents, sr-using-git-worktrees, using-super-ralph, sr-writing-skills.

## Updating

```bash
cd ~/.codex/super-ralph && git pull
```

Skills update instantly through the symlink.

## Uninstalling

```bash
rm ~/.agents/skills/super-ralph
```

Optionally delete the clone: `rm -rf ~/.codex/super-ralph`.
