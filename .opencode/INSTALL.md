# Installing Super-Ralph for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- Git installed

## Installation Steps

### 1. Clone Super-Ralph

```bash
git clone https://github.com/aezizhu/super-ralph.git ~/.config/opencode/super-ralph
```

### 2. Symlink Skills

Create a symlink so OpenCode's native skill tool discovers super-ralph skills:

```bash
mkdir -p ~/.config/opencode/skills
rm -rf ~/.config/opencode/skills/super-ralph
ln -s ~/.config/opencode/super-ralph/plugins/super-ralph/skills ~/.config/opencode/skills/super-ralph
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\opencode\skills"
cmd /c mklink /J "$env:USERPROFILE\.config\opencode\skills\super-ralph" "$env:USERPROFILE\.config\opencode\super-ralph\skills"
```

### 3. Restart OpenCode

Restart OpenCode. The skills will be automatically discovered.

Verify by asking: "do you have super-ralph skills?"

## Usage

### Finding Skills

Use OpenCode's native `skill` tool to list available skills:

```
use skill tool to list skills
```

### Loading a Skill

Use OpenCode's native `skill` tool to load a specific skill:

```
use skill tool to load super-ralph/sr-brainstorming
use skill tool to load super-ralph/sr-test-driven-development
use skill tool to load super-ralph/sr-systematic-debugging
```

## Available Skills (14 total)

- `sr-brainstorming` - Collaborative design before coding
- `sr-writing-plans` - Bite-sized implementation plans with exact file paths
- `sr-test-driven-development` - Strict RED-GREEN-REFACTOR with iron law enforcement
- `sr-systematic-debugging` - 4-phase root cause investigation before fixes
- `sr-verification-before-completion` - Evidence before completion claims
- `sr-subagent-driven-development` - Fresh subagent per task + two-stage review
- `sr-executing-plans` - Batch execution with human checkpoints
- `sr-requesting-code-review` - Dispatch code-reviewer subagent
- `sr-receiving-code-review` - Technical evaluation, not performative agreement
- `sr-finishing-a-development-branch` - Verify tests, present 4 options, clean up
- `sr-dispatching-parallel-agents` - One agent per independent problem domain
- `sr-using-git-worktrees` - Isolated workspaces with safety verification
- `using-super-ralph` - Master orchestrator: invoke skills before any action
- `sr-writing-skills` - TDD applied to process documentation

## Updating

```bash
cd ~/.config/opencode/super-ralph && git pull
```

## Uninstalling

```bash
rm ~/.config/opencode/skills/super-ralph
rm -rf ~/.config/opencode/super-ralph
```
