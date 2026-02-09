# Super-Ralph

[![Tests](https://github.com/aezizhu/super-ralph/actions/workflows/test.yml/badge.svg)](https://github.com/aezizhu/super-ralph/actions/workflows/test.yml)

**Ralph's autonomous development loop + Superpowers' disciplined methodology = production-ready autonomous AI development.**

Super-Ralph fuses two proven open-source projects into a unified system:

- **[Ralph](https://github.com/frankbria/ralph-claude-code)** (MIT) -- An autonomous AI development loop for Claude Code with intelligent exit detection, rate limiting, circuit breakers, session continuity, and a comprehensive bash-based orchestration system (465+ tests, 100% pass rate).
- **[Superpowers](https://github.com/obra/superpowers)** (MIT) -- A composable skills framework and software development methodology that enforces brainstorming, TDD, systematic debugging, two-stage code review, and verification-before-completion workflows across AI coding agents.

Ralph gives your AI agent **endurance** (it can run autonomously for hours). Superpowers gives it **discipline** (it follows engineering best practices instead of ad-hoc implementation). Super-Ralph combines both.

---

## Table of Contents

- [Installation (Claude Code)](#installation-claude-code)
- [Why Super-Ralph Exists](#why-super-ralph-exists)
- [What's Inside](#whats-inside)
  - [Bash System (Ralph Infrastructure)](#bash-system-ralph-infrastructure)
  - [Skills Library](#skills-library)
  - [Integration Layer](#integration-layer)
- [The Super-Ralph Loop](#the-super-ralph-loop)
- [Skills Reference](#skills-reference)
- [Other Platforms](#other-platforms)
  - [Codex](#codex)
  - [OpenCode](#opencode)
  - [Other Tools (Cursor, Warp, Amp, etc.)](#other-tools-cursor-warp-amp-etc)
  - [Standalone Bash System](#standalone-bash-system)
- [Architecture](#architecture)
- [Attribution & License](#attribution--license)

---

## Installation (Claude Code)

> **Note:** Super-Ralph includes all skills from the [Superpowers](https://github.com/obra/superpowers) plugin. If you have Superpowers installed, you can uninstall it after installing Super-Ralph to avoid duplicate skills.

### Step 1: Add the marketplace

In Claude Code, run:

```
/plugin add https://github.com/aezizhu/super-ralph
```

This registers Super-Ralph as a plugin marketplace. Claude Code will clone the repo and discover the plugin.

### Step 2: Install the plugin

After adding the marketplace, Claude Code will show **super-ralph** as an available plugin. Select it to install.

### Step 3: Restart Claude Code

Exit and reopen Claude Code. Start with:

```
/using-super-ralph "Your task here" --max-iterations 15
```

This starts the autonomous loop with full methodology enforcement. All 14 skills + 3 commands are available:

```
# Commands
/using-super-ralph          Start Super-Ralph loop (main entry point)
/sr-cancel-ralph            Cancel an active loop
/sr-help                    Show all commands and skills

# Skills (auto-triggered)
/sr-brainstorming           Explore intent, requirements, and design before coding
/sr-writing-plans           Create detailed implementation plans with bite-sized tasks
/sr-test-driven-development Strict RED-GREEN-REFACTOR TDD workflow
/sr-systematic-debugging    4-phase root cause investigation before any fix
/sr-verification-before-completion  Evidence before claims — run commands, read output
/sr-subagent-driven-development     Fresh subagent per task with two-stage review
/sr-executing-plans         Execute plans in batches with human checkpoints
/sr-requesting-code-review  Dispatch code-reviewer subagent on git diff
/sr-receiving-code-review   Technical evaluation of review feedback, not blind agreement
/sr-finishing-a-development-branch  Verify tests → merge/PR/keep/discard
/sr-using-git-worktrees     Isolated workspaces for feature development
/sr-dispatching-parallel-agents     One agent per independent problem domain
/sr-writing-skills          TDD for skills — test scenarios before writing
```

### Updating

```
/plugin update super-ralph
```

### Uninstalling

Use `/plugin` to browse installed plugins and remove Super-Ralph.

---

## Why Super-Ralph Exists

Ralph alone is a powerful autonomous loop, but it has gaps that Superpowers fills:

| Ralph Default | Super-Ralph Enhancement |
|---------------|------------------------|
| Jumps straight to implementation | Brainstorms design first, validates with user |
| Tests as afterthought | Enforces strict TDD: test first, watch fail, implement |
| Works on main branch | Uses git worktrees for isolation |
| Reviews code informally | Two-stage review: spec compliance then code quality |
| "Fix plan says done" = done | Verification-before-completion: evidence before claims |
| Serial task execution | Subagent-driven development with fresh agents per task |
| Guesses at bug fixes | Systematic 4-phase debugging: root cause before fix |
| No structured planning | Bite-sized tasks with exact file paths and commands |

---

## What's Inside

### Bash System (Ralph Infrastructure)

The bash system replicates and extends Ralph's autonomous loop infrastructure:

| Component | File | Description |
|-----------|------|-------------|
| **Main Loop** | `standalone/super_ralph_loop.sh` | The autonomous development loop. Runs Claude Code in a loop with rate limiting (configurable calls/hour), circuit breaker pattern (stops after repeated failures), intelligent exit detection (dual-condition gate: completion indicators + EXIT_SIGNAL), and session continuity. Injects Super-Ralph methodology context via `--append-system-prompt` on every iteration. Operates in dual mode: reuses Ralph's libraries when installed, or runs standalone with built-in infrastructure. |
| **Skill Selector** | `standalone/lib/skill_selector.sh` | Classifies tasks from `fix_plan.md` into types (FEATURE, BUG, PLAN_TASK, REVIEW, COMPLETION) and maps each type to the appropriate Super-Ralph skill workflow chain. For example, a FEATURE triggers brainstorming -> writing-plans -> TDD, while a BUG triggers systematic-debugging -> TDD. Recognizes broad vocabulary: BUG (fix, bug, error, broken, crash, regression, resolve, repair, correct, hotfix, patch), FEATURE (add, create, implement, build, enhance, extend, expand), and more. Provides functions: `classify_task()`, `get_skill_workflow()`, `get_current_task()`, `has_design_doc()`, `has_implementation_plan()`, `all_tasks_complete()`, `count_remaining_tasks()`. |
| **TDD Gate** | `standalone/lib/tdd_gate.sh` | Analyzes Claude's output for TDD compliance. Pattern-matches against RED indicators (test written, test fails, failing test), GREEN indicators (test passes, all tests pass, tests green), and VIOLATION indicators (skip test, implement first, test later, no test needed). Produces a JSON compliance report with pass/fail status. Functions: `check_tdd_compliance()`, `analyze_tdd_status()`, `log_tdd_summary()`, `get_tdd_enforcement_context()`. |
| **Verification Gate** | `standalone/lib/verification_gate.sh` | Detects unverified completion claims vs evidence-based claims. Matches UNVERIFIED patterns ("should pass", "looks correct", "probably works", "seems to") against VERIFIED patterns ("34/34 pass", "exit code 0", "0 failures", "all tests pass"). Blocks exit signals that lack verification evidence. Functions: `check_verification()`, `analyze_verification_status()`, `log_verification_summary()`, `validate_exit_signal()`. |
| **Session Manager** | `standalone/lib/session_manager.sh` | Manages Claude session persistence with expiry tracking. Handles cross-platform file age detection (GNU/BSD stat), session initialization, save/restore, and reset. Functions: `get_session_file_age_hours()`, `init_claude_session()`, `save_claude_session()`, `init_session_tracking()`, `update_session_last_used()`, `reset_session()`. |
| **TMUX Utils** | `standalone/lib/tmux_utils.sh` | Sets up multi-pane tmux monitoring sessions with live output, status display, and the main loop running side-by-side. Functions: `check_tmux_available()`, `setup_tmux_session()`. |
| **Exit Detector** | `standalone/lib/exit_detector.sh` | Determines when the loop should stop based on signal analysis: test saturation, completion signals, permission denials, safety circuit breaker, and verification gates. Also validates `.ralphrc` configuration values. Functions: `should_exit_gracefully()`, `validate_ralphrc()`. |
| **Logging** | `standalone/lib/logging.sh` | Shared colored logging with file output. Provides `log_status()` with 6 levels (INFO, WARN, ERROR, SUCCESS, LOOP, SKILL), color constants, and optional file logging via `$LOG_DIR`. Auto-sourced by all libraries that need logging. |
| **Installer** | `standalone/install.sh` | Installs `super-ralph` and `super-ralph-setup` commands globally to `~/.local/bin`. Copies libraries to `~/.super-ralph/`. Includes embedded `super-ralph-setup` script for project scaffolding (creates `.ralph/` directory structure with PROMPT.md, specs/, fix_plan.md). Supports `./install.sh uninstall` for clean removal with verification. |
| **Enhanced Prompt** | `standalone/super-ralph-prompt.md` | Drop-in replacement for Ralph's `.ralph/PROMPT.md`. Contains the full Super-Ralph methodology embedded as prompt context: task classification table, TDD workflow (RED-VERIFY-GREEN-VERIFY-REFACTOR-COMMIT), systematic debugging 4-phase process, verification enforcement, and skill selection logic. This is what Claude reads on every loop iteration. |

### Skills Library

14 skills based on the [Superpowers](https://github.com/obra/superpowers) methodology, adapted for Super-Ralph with `sr-` prefixed names to avoid conflicts when both plugins are installed. Each skill is a standalone `SKILL.md` file with YAML frontmatter and markdown instructions.

```
plugins/super-ralph/skills/
  using-super-ralph/SKILL.md
  sr-brainstorming/SKILL.md
  sr-writing-plans/SKILL.md
  sr-test-driven-development/SKILL.md
  sr-test-driven-development/testing-anti-patterns.md
  sr-systematic-debugging/SKILL.md
  sr-systematic-debugging/root-cause-tracing.md
  sr-systematic-debugging/defense-in-depth.md
  sr-systematic-debugging/condition-based-waiting.md
  sr-verification-before-completion/SKILL.md
  sr-subagent-driven-development/SKILL.md
  sr-subagent-driven-development/implementer-prompt.md
  sr-subagent-driven-development/spec-reviewer-prompt.md
  sr-subagent-driven-development/code-quality-reviewer-prompt.md
  sr-executing-plans/SKILL.md
  sr-requesting-code-review/SKILL.md
  sr-requesting-code-review/code-reviewer.md
  sr-receiving-code-review/SKILL.md
  sr-finishing-a-development-branch/SKILL.md
  sr-dispatching-parallel-agents/SKILL.md
  sr-using-git-worktrees/SKILL.md
  sr-writing-skills/SKILL.md
```

### Integration Layer

| File | Description |
|------|-------------|
| `docs/ralph-integration-guide.md` | Explains the 3-layer architecture (Infrastructure / Prompt / Methodology), setup options for existing Ralph projects (replace PROMPT.md, augment existing, CLAUDE.md integration), compatibility notes (RALPH_STATUS extension, circuit breaker interaction, session continuity), and troubleshooting guide. |
| `docs/ralph-skill-hooks.md` | Decision tables for automatic skill selection at each loop phase: task classification hook (IF feature/bug/plan/review -> skill workflow), between-task hook (review -> fix -> verify -> commit -> mark complete), loop-end hook (run tests -> set status), parallel task hook, and error recovery hook. |

---

## The Super-Ralph Loop

Each Ralph loop iteration follows this enhanced flow:

```
RALPH LOOP ITERATION START
|
+-- 1. READ: Load .ralph/fix_plan.md, .ralph/specs/*, .ralph/AGENT.md
|
+-- 2. CLASSIFY: What type of work is the current task?
|   |
|   +-- NEW FEATURE ----------> sr-brainstorming -> sr-writing-plans -> sr-using-git-worktrees -> sr-test-driven-development
|   +-- BUG FIX --------------> sr-systematic-debugging -> sr-test-driven-development
|   +-- IMPLEMENTATION TASK --> sr-test-driven-development (with sr-subagent-driven-development or sr-executing-plans)
|   +-- COMPLETION/REVIEW ----> sr-verification-before-completion -> sr-requesting-code-review -> sr-finishing-a-development-branch
|
+-- 3. EXECUTE: Follow the skill workflow for the task type
|
+-- 4. REPORT: Output RALPH_STATUS block with methodology tracking
|
RALPH LOOP ITERATION END
```

The enhanced RALPH_STATUS includes:

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: <number>
FILES_MODIFIED: <number>
TESTS_STATUS: PASSING | FAILING | NOT_RUN
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION | DEBUGGING | REFACTORING
EXIT_SIGNAL: false | true
METHODOLOGY: BRAINSTORMING | PLANNING | TDD | DEBUGGING | REVIEW | VERIFICATION
SKILL_USED: <skill-name or none>
RECOMMENDATION: <one line summary>
---END_RALPH_STATUS---
```

---

## Skills Reference

### Brainstorming

**Trigger:** New feature request or creative work that requires design decisions.

Turns rough ideas into fully formed designs through collaborative dialogue. Instead of jumping to code, the agent asks questions one at a time, explores 2-3 approaches with trade-offs, and presents the design in 200-300 word sections for incremental validation. Key principles: one question at a time, multiple choice preferred, YAGNI ruthlessly, explore alternatives always. Output: design document saved to `docs/plans/YYYY-MM-DD-<topic>-design.md`.

### Writing Plans

**Trigger:** Approved design ready for implementation breakdown.

Creates comprehensive implementation plans with bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, test commands, and expected output. Assumes the implementer has zero codebase context and questionable taste. Each step is one action: "Write the failing test" is a step, "Run it to make sure it fails" is another step. Plans enforce DRY, YAGNI, TDD, and frequent commits. Output: plan document saved to `docs/plans/YYYY-MM-DD-<feature-name>.md`.

### Test-Driven Development

**Trigger:** Any implementation work -- features, bug fixes, refactoring, behavior changes.

Enforces strict RED-GREEN-REFACTOR cycle. The Iron Law: **NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.** Write code before the test? Delete it. Start over. No exceptions -- don't keep it as "reference", don't "adapt" it, don't look at it. Delete means delete. Each cycle: write one minimal failing test (RED), verify it fails for the right reason, write simplest code to pass (GREEN), verify all tests pass, refactor keeping green. Includes comprehensive rationalization prevention table (12 common excuses with rebuttals), verification checklist, and testing anti-patterns reference (never test mock behavior, never add test-only methods to production, never mock without understanding dependencies).

### Systematic Debugging

**Trigger:** Any technical issue -- test failures, bugs, unexpected behavior, performance problems, build failures.

The Iron Law: **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** Four mandatory phases: (1) Root Cause Investigation -- read errors carefully, reproduce consistently, check recent changes, gather evidence in multi-component systems, trace data flow backward to source; (2) Pattern Analysis -- find working examples, compare against references, identify differences; (3) Hypothesis and Testing -- form single hypothesis, test minimally, one variable at a time; (4) Implementation -- create failing test case first (TDD), implement single fix, verify. After 3 failed fix attempts: STOP and question the architecture. Includes supporting techniques: root-cause-tracing (trace backward through call chain), defense-in-depth (validate at every layer), condition-based-waiting (replace arbitrary timeouts with condition polling).

### Verification Before Completion

**Trigger:** Before ANY completion claim, positive statement about work state, commit, PR, or task completion.

The Iron Law: **NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.** The Gate Function: (1) IDENTIFY what command proves the claim, (2) RUN the full command fresh, (3) READ full output and check exit code, (4) VERIFY output confirms the claim, (5) ONLY THEN make the claim. Skip any step = lying, not verifying. Red flags: using "should", "probably", "seems to"; expressing satisfaction before verification; trusting agent success reports; relying on partial verification. "Tests pass" requires test command output showing 0 failures, not "should pass now".

### Subagent-Driven Development

**Trigger:** Implementation plan with mostly independent tasks, staying in current session.

Dispatches fresh subagent per task with two-stage review after each: spec compliance review first (did they build what was requested?), then code quality review (is it well-built?). The coordinator reads the plan, extracts tasks with full text, creates a todo list, then per task: dispatch implementer subagent (with full task text, not file reference), wait for completion, dispatch spec reviewer (who does NOT trust the implementer's report -- reads actual code), fix issues, dispatch code quality reviewer, fix issues, mark complete. After all tasks: dispatch final code reviewer for entire implementation. Includes three prompt templates: implementer, spec-reviewer, code-quality-reviewer.

### Executing Plans

**Trigger:** Implementation plan to execute in batches with human checkpoints.

Alternative to sr-subagent-driven-development. Loads plan, reviews critically, executes tasks in batches of 3 (default), reports progress between batches with verification output, waits for feedback, continues. Stops immediately on blockers instead of guessing. Uses sr-finishing-a-development-branch when all tasks complete.

### Requesting Code Review

**Trigger:** After each task, after major features, before merge.

Dispatches code-reviewer subagent with git SHA range (base..head) to review changes. Reviewer checks code quality, architecture, testing, requirements, and production readiness. Issues categorized as Critical (must fix), Important (should fix), Minor (nice to have). Critical issues block progress, Important issues fixed before proceeding, Minor noted for later.

### Receiving Code Review

**Trigger:** When receiving code review feedback from any source.

Code review requires technical evaluation, not emotional performance. Forbidden responses: "You're absolutely right!", "Great point!", "Let me implement that now" (before verification). Instead: restate the technical requirement, ask clarifying questions, push back with technical reasoning if wrong. YAGNI check: if reviewer suggests "implementing properly", grep codebase for actual usage -- if unused, remove it. Implementation order: clarify unclear items first, then blocking issues, simple fixes, complex fixes, testing each individually.

### Finishing a Development Branch

**Trigger:** All tasks complete, ready to integrate.

Verify tests -> Present exactly 4 options (merge locally, push and create PR, keep as-is, discard) -> Execute chosen workflow -> Clean up worktree. Will not proceed with failing tests. Discard requires typed confirmation. Cleanup worktree for merge/PR/discard, keep for "as-is".

### Using Git Worktrees

**Trigger:** Starting feature work that needs isolation from current workspace.

Creates isolated git worktrees with systematic directory selection (check for existing `.worktrees` or `worktrees`, ask user if neither exists) and safety verification (ensure directory is in `.gitignore`). Auto-detects project setup (package.json -> npm install, Cargo.toml -> cargo build, etc.) and verifies clean test baseline before reporting ready.

### Dispatching Parallel Agents

**Trigger:** 3+ independent failures in different subsystems/test files.

When multiple unrelated problems exist, dispatch one agent per independent domain. Each agent gets specific scope, clear goal, constraints, and expected output format. After agents return: review summaries, check for conflicts, run full test suite, spot check. Do NOT use when failures are related (fix one might fix others), need full system context, or agents would interfere with each other.

### Using Super-Ralph

**Trigger:** Every conversation -- establishes skill invocation requirement.

The master orchestrator skill. If there is even a 1% chance a skill might apply to what you're doing, you ABSOLUTELY MUST invoke the skill. This is not negotiable. Skill check comes BEFORE any response or action, including clarifying questions. Priority: process skills first (sr-brainstorming, sr-systematic-debugging), implementation skills second.

### Writing Skills

**Trigger:** Creating new skills, editing existing skills, or verifying skills work.

Writing skills IS Test-Driven Development applied to process documentation. You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes). The Iron Law: NO SKILL WITHOUT A FAILING TEST FIRST. Skill description must start with "Use when..." and describe ONLY triggering conditions, never summarize the skill's process.

---

## Other Platforms

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/aezizhu/super-ralph/refs/heads/main/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/aezizhu/super-ralph/refs/heads/main/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

### Other Tools (Cursor, Warp, Amp, etc.)

For tools that read project-level instructions, clone into your project and reference from the tool's config file:

```bash
cd your-project
git clone https://github.com/aezizhu/super-ralph.git .super-ralph
echo ".super-ralph/" >> .gitignore
```

Then reference in your tool's instruction file (AGENTS.md, .cursorrules, etc.):
```
Read and follow the skills in .super-ralph/plugins/super-ralph/skills/ for all development work.
```

### Standalone Bash System

```bash
git clone https://github.com/aezizhu/super-ralph.git
cd super-ralph
./standalone/install.sh
```

This installs:
- `super-ralph` command -- the autonomous development loop
- `super-ralph-setup` command -- project scaffolding
- `~/.super-ralph/` -- libraries and templates

Usage:
```bash
super-ralph-setup my-project    # Create new project
cd my-project
super-ralph --verbose           # Run the loop
```

---

## Troubleshooting

If the loop stops unexpectedly, enable debug logging:

```bash
export SUPER_RALPH_DEBUG=1
```

Then run `/using-super-ralph` again. Check `.claude/super-ralph-debug.log` in your project directory for the stop hook execution trace.

---

## Architecture

Super-Ralph operates in three layers:

```
Layer 3: METHODOLOGY (Superpowers Skills)
  - 14 composable skills with iron laws, gate functions, rationalization prevention
  - Task classification -> skill workflow selection
  - TDD enforcement, systematic debugging, verification gates

Layer 2: PROMPT (Enhanced PROMPT.md)
  - Injected into Claude on every loop iteration via --append-system-prompt
  - Contains task classification logic, methodology references, RALPH_STATUS format
  - Drop-in replacement for Ralph's default PROMPT.md

Layer 1: INFRASTRUCTURE (Ralph Loop)
  - Autonomous bash loop with rate limiting and circuit breaker
  - Session continuity and intelligent exit detection
  - Monitoring, logging, and call tracking
```

**Dual Mode Operation:**
- **With Ralph installed:** Reuses Ralph's circuit breaker, response analyzer, date/timeout utils, session management. Adds Super-Ralph methodology layer on top.
- **Without Ralph:** Runs standalone with built-in rate limiting, call tracking, exit detection, and all Super-Ralph features.

---

## Development & Testing

Super-Ralph includes a comprehensive test suite with **295 bats tests** across 13 test files covering all gate libraries, the stop-hook controller, session management, exit detection, config validation, rate limiting, logging, project setup, SKILL.md consistency, and shared utilities.

```bash
# Install bats (macOS)
brew install bats-core

# Run all tests
make test

# Run all checks (lint + test + version consistency)
make check

# Run a specific test file
bats tests/test_skill_selector.bats

# Lint all scripts with ShellCheck
make lint

# Bump version across all config files
make release VERSION=x.y.z
```

Test files:

| File | Coverage |
|------|----------|
| `tests/test_auto_detect.bats` | Project type auto-detection (31 tests) |
| `tests/test_gate_utils.bats` | Shared pattern matching utilities |
| `tests/test_skill_selector.bats` | Task classification engine (52 tests) |
| `tests/test_tdd_gate.bats` | TDD compliance enforcement |
| `tests/test_verification_gate.bats` | Completion claim validator |
| `tests/test_stop_hook.bats` | Loop controller behavior (25 tests) |
| `tests/test_session_manager.bats` | Session persistence and expiry |
| `tests/test_tmux_utils.bats` | TMUX monitoring and command assembly (12 tests) |
| `tests/test_exit_detector.bats` | Exit detection and config validation (36 tests) |
| `tests/test_main_loop.bats` | Validate tools, load config, and rate limiting (34 tests) |
| `tests/test_setup.bats` | Project scaffolding and SKILL.md consistency validation |
| `tests/test_logging.bats` | Shared logging and color constants |
| `tests/test_install.bats` | Installation, uninstallation, and PATH detection (16 tests) |

Key engineering features:
- **Configurable constants**: All timing values, thresholds, and limits are environment-variable configurable (`MAX_CALLS_PER_HOUR`, `RETRY_BACKOFF_SECONDS`, `RATE_LIMIT_RETRY_SECONDS`, `MAX_LOOP_CONTEXT_LENGTH`, etc.)
- **8 extracted libraries**: Logging, session management, TMUX utils, exit detection, skill selection, TDD gate, verification gate, and shared gate utilities -- each independently testable and self-contained
- **SKILL.md consistency**: All 14 skills have standardized YAML frontmatter (`name`, `description` starting with "Use when"), and `## Related Skills` cross-references, validated by CI tests
- **Project auto-detection**: Automatically configures allowed tools based on project files (package.json, Cargo.toml, pyproject.toml, go.mod, etc.)
- **ShellCheck clean**: All bash scripts pass shellcheck static analysis
- **CI/CD**: GitHub Actions workflow runs `make test`, `make lint`, and `make version-check` on macOS and Linux

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

---

## Attribution & License

MIT License. See [LICENSE](LICENSE).

Super-Ralph is built on top of two excellent open-source projects:

- **[Superpowers](https://github.com/obra/superpowers)** by Jesse Vincent ([@obra](https://github.com/obra)) -- The complete skills framework and software development methodology. All 14 skills and supporting files in the `skills/` directory are adapted from the Superpowers project (v4.2.0) with sr- prefixed names. MIT License.

- **[Ralph](https://github.com/frankbria/ralph-claude-code)** by Frank Bria ([@frankbria](https://github.com/frankbria)) -- The autonomous AI development loop for Claude Code. The bash system (`standalone/super_ralph_loop.sh`, `standalone/install.sh`, and library files) is inspired by and extends Ralph's architecture (v0.11.4). MIT License.

If Superpowers or Ralph has helped you, consider [sponsoring Jesse's work](https://github.com/sponsors/obra) and [starring Ralph](https://github.com/frankbria/ralph-claude-code).
