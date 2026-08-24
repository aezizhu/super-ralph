# Changelog

All notable changes to Super-Ralph are documented in this file.

## [Unreleased]

### sync-upstream-2026-08

Upstream sync against `obra/superpowers` (through v6.3.0, 2026-08-12)
and `frankbria/ralph-claude-code` through 2026-08-24.

#### Superpowers skill ports

- **sr-brainstorming** — Three Paths router (spike / bounded /
  architectural) with per-path checklists, Red Flags table, path-bound
  terminal states; approval gate now applies to every path.
- **sr-subagent-driven-development** — Plan-scoped SDD workspace
  (`.superpowers/sdd/<plan-basename>/`), new re-review-prompt.md for
  scoped re-reviews after fix rounds, updated implementer and
  task-reviewer prompts, major SKILL.md rewrite (controller discipline,
  re-review flow, residual adjudication). Scripts sdd-workspace,
  task-brief, review-package now take the plan file as first argument.
- **sr-test-driven-development** — testing-anti-patterns.md replaced by
  writing-good-tests.md (rules for honest tests); expanded
  rationalization rebuttals.
- **sr-finishing-a-development-branch** — Discard removed from the menu
  (explicit-request only), 3/2-option menus, worktree-removal-refused
  handling, Common Rationalizations table replaces Common
  Mistakes/Red Flags.
- **sr-using-git-worktrees** — Common Rationalizations table replaces
  Common Mistakes/Red Flags.
- **sr-requesting-code-review** — Tightened overview; Common
  Rationalizations table; code-reviewer.md gains "You Do Not Dispatch
  Subagents" section.
- **sr-executing-plans** — Workspace isolation is now Step 1 of plan
  review (three-task batching intentionally retained).
- **sr-writing-plans** — Plan header now carries a Spec pointer;
  removed redundant Remember section.
- **sr-systematic-debugging / sr-verification-before-completion /
  sr-receiving-code-review / sr-dispatching-parallel-agents** — Trimmed
  redundant closing sections; Phase 4 verification now points at
  sr-verification-before-completion.

Ralph upstream fixes (zero-length output guard in response analyzer,
tmux base-index detection after server start) reviewed; not ported —
the corresponding code paths do not exist in Super-Ralph's standalone
implementation.

### sync-upstream-2026-06

Upstream sync against `frankbria/ralph-claude-code` (37 commits) and
`obra/superpowers` (172 commits, 65 touching skills/) through
2026-06-24.

#### Superpowers skill ports

- **sr-subagent-driven-development** — Major rewrite: unified
  task-reviewer replaces two-stage spec-reviewer + code-quality-reviewer.
  New task-reviewer-prompt.md, updated implementer-prompt.md with TDD
  Evidence and file-based brief. New scripts: sdd-workspace, task-brief,
  review-package. Old spec-reviewer-prompt.md and
  code-quality-reviewer-prompt.md deleted.
- **sr-finishing-a-development-branch** — Added Step 2 (GIT_DIR vs
  GIT_COMMON environment detection), detached HEAD conditional menu
  (3 vs 4 options), Step 6 provenance-based cleanup.
- **sr-using-git-worktrees** — Added Step 0 (Detect Existing Isolation)
  with submodule guard, restructured Steps 1a/1b with native tool priority.
- **sr-writing-plans** — Added Scope Check, Task Right-Sizing, File
  Structure, Global Constraints, Interfaces blocks, Execution Handoff.
- **sr-brainstorming** — Added HARD-GATE, Anti-Pattern section, 8-item
  checklist, Design for isolation, Working in existing codebases, User
  Review Gate.
- **sr-requesting-code-review** — Updated checklist with Structure
  section, updated Assessment format.
- **sr-receiving-code-review** — Added Gracefully Correcting Pushback,
  GitHub Thread Replies sections.
- **sr-systematic-debugging** — Added Don't skip when, expanded Phase 1
  error reading, Your Human Partner's Signals, When Process Reveals No
  Root Cause.
- **sr-test-driven-development** — Updated description for SDO, added
  manual testing rebuttal, TDD pragmatism/spirit rebuttals, bug fix
  example.
- **sr-verification-before-completion** — Updated description for SDO,
  added regression test pattern, Why This Matters section, expanded
  rationalization table, Rule applies to section.
- **sr-writing-skills** — Added TDD Mapping table, Skill Types, SDO
  section (Rich Description, Keyword Coverage, Token Efficiency), Match
  Form to Failure, expanded Iron Law, Testing All Skill Types,
  Bulletproofing Against Rationalization.
- **sr-dispatching-parallel-agents** — Added decision flowchart, dispatch
  example with parallel semantics, Real-World Impact section.

#### Ralph upstream bug fixes

- **Session ID corruption** (upstream #254) — `init_claude_session` and
  `save_claude_session` now strip multi-line jq output and CR characters
  to prevent `--resume` failures with corrupted session files.
- **Tmux pane-base-index** (upstream #259) — `setup_tmux_session` now
  reads `pane-base-index` and computes dynamic pane indices instead of
  hardcoding `.0/.1/.2`.
- **Arithmetic crash prevention** (upstream #255, #251, #260) — Added
  `_safe_count` helper to normalize grep count output for bash arithmetic;
  replaced unsafe `grep -cE … || true` patterns in loop and skill selector.

---

## Previous

Upstream sync against `frankbria/ralph-claude-code` and
`obra/superpowers` through 2026-04-23. Details of each port live in
the corresponding `sync-upstream-2026-04` commit.

### Fixed — Ralph upstream ports

Loop stability, set-e resilience, and API-limit detection.

- **P1 (1233995)** Auto-terminate tmux session when loop exits so the
  `tail -f` / `watch` panes don't keep the window open.
- **P2 (fe64f2b)** Wrap the live-mode pipeline with `set +e` / `set -e`
  (superseded by Wave 6's removal of global `set -e`, but the
  explicit no-errexit-across-pipefail behavior remains).
- **P3 (117fed7)** `read -t 30 -n 1 user_choice || true` so the
  API-limit prompt's read timeout doesn't kill the script.
- **P4 (1ea2776)** Three-layer API-limit detection: exit-code-124
  guard, structural `rate_limit_event` JSON probe, tail-30 filtered
  text fallback that skips `type:user` / `tool_result` /
  `tool_use_id` lines.
- **P5 (5bb8111, 3126777)** Whitespace-tolerant regexes on the Layer
  2 and Layer 3 filters.
- **P7 (2cf2bf3)** Detect `is_error:true` in the Claude CLI JSON
  output even when exit code is 0. Reset the session rather than
  persist a bad ID.
- **P8 (12e4710)** Reset `.exit_signals` + remove stale
  `.response_analysis` before the main loop so a killed run can't
  trigger a loop-1 graceful exit. Also reset session in the
  API-limit user-exit branch.
- **P9 (13e35c4)** Productive-timeout handling — when
  `portable_timeout` returns 124 but git shows files changed, run
  the full analysis pipeline and return 0 instead of 1.
- **P10 (f1298b8)** Layer-4 "Extra Usage" quota detection plus an
  updated user-facing prompt that covers both the 5-hour plan limit
  and Extra Usage.
- **P11 (3fe66f6)** Guard `log_status()` writes against broken tmux
  pty so dead panes don't kill the loop.
- **P12 (40bb335)** Drop `stdbuf` from the `--live` pipeline;
  Homebrew coreutils `stdbuf` is rejected by `/usr/bin/tee` on
  arm64e Apple Silicon.
- **P13 (f702543)** Emit readable `[agent ... started/progress]`
  lines in `--live` mode so sub-agent dispatch no longer looks like
  a hang.
- **P14 (24b8969)** Always run stream-json result-line extraction
  when the output file exists; previous `CLAUDE_USE_CONTINUE` guard
  left raw stream frames in place.
- **P15 (13b2413)** Route Claude CLI stderr to a separate file so
  Node/undici warnings can't corrupt the JSON stream fed to jq.
- **P16 (6ff27b4)** Persist `$CALL_COUNT_FILE` immediately on each
  call (not only on success) so the monitor dashboard reflects real
  API usage.
- **P17 (be6c96a)** Build loop context unconditionally —
  `CLAUDE_USE_CONTINUE=false` runs previously shipped no loop number
  / circuit-breaker state / previous summary.

### Added — Ralph upstream adapts

- **A1 (5ae0d21, 7c01c73)** `standalone/lib/file_protection.sh` with
  Super-Ralph-specific `RALPH_REQUIRED_PATHS` and a recovery hint
  that points at `super-ralph-setup` instead of `ralph-enable`. Loop
  now validates `.ralph/` integrity before entering the main loop;
  Protected Files section added to `super-ralph-prompt.md`.
- **A2 (4383e99)** `validate_claude_command()` pre-flight check in
  `main()` + early background-failure detection so a missing
  `CLAUDE_CODE_CMD` no longer hangs.
- **A3 (b31640a)** Move `CLAUDE_CODE_CMD` default after the env
  snapshot; add `CLAUDE_MODEL` / `CLAUDE_EFFORT` config (env +
  `.ralphrc` + CLI) wired through `build_claude_command` as
  `--model` / `--effort`.
- **A4 (8c7a7d9)** `MAX_TOKENS_PER_HOUR` alternative rate limit
  (0 = disabled) with `.token_count` file,
  `extract_token_usage` / `update_token_count`, composite
  `wait_for_reset` reason, and `tokens_used_this_hour` /
  `max_tokens_per_hour` in `status.json`. Adds
  `RALPH_SHELL_INIT_FILE` (with `SUPER_RALPH_SHELL_INIT_FILE`
  taking precedence) so zsh-only users can load `~/.zshrc` before
  `claude` runs.
- **A5 (9f5cc34)** `DRY_RUN` + `--dry-run` CLI flag + early return
  in `execute_super_ralph` so CI smoke tests don't burn API calls.
- **A6 (56b2c3e, adapted)** `standalone/lib/log_utils.sh` rotates
  Super-Ralph's per-iteration `claude_output_*.log` directory by
  age (`SUPER_RALPH_LOG_RETENTION_DAYS`, default 7) instead of
  upstream's `ralph.log.N` scheme. Called at the top of each loop
  iteration.
- **A7 (dc89f16)** `track_metrics()` writes a JSON-Lines record per
  loop to `.ralph/logs/metrics.jsonl`; `print_metrics_summary()`
  fires on graceful exit; new `standalone/super-ralph-stats.sh`
  analytics helper installed by `standalone/install.sh`.
- **A8 (a1f6d5f)** Cross-platform `send_notification()` helper
  (osascript / notify-send / bell fallback), `-n` / `--notify`
  CLI flag, `ENABLE_NOTIFICATIONS` opt-in (default false). Fires
  at graceful exit, rate limit / API limit, circuit-breaker trip,
  and execution failure.
- **A9 (da2f157, e13a3cb)** `ENABLE_BACKUP` opt-in with
  `-b` / `--backup` CLI flag (default false; `_cli_ENABLE_BACKUP`
  ensures the flag outranks `.ralphrc ENABLE_BACKUP=false`).
  `create_backup()` uses the `super-ralph-backup-loop-*` prefix
  (distinct from Ralph's), stashes local changes before checkout,
  and reports failures via `log_status`. `--rollback [BRANCH]`
  lists newest-first or checks out a named backup. Tmux setup
  forwards both `--notify` and `--backup`.

### Changed — Ralph upstream refactor

- **A10 (8237aa3, adapted)** Removed `set -e` from
  `standalone/super_ralph_loop.sh`. `set -e` was the root cause of
  several already-ported bugs (P2, P3, P11). Required `source` lines
  now guard themselves explicitly with `|| { echo FATAL; exit 1; }`,
  pipefail is still enabled around the live-mode pipeline via local
  `set -o pipefail` / `set +o pipefail`, and `cleanup()` has a
  re-entrancy guard so a second SIGINT during teardown can't
  re-enter `reset_session`.

### Changed — Superpowers skill ports

Skill docs updated in place; no file renames in this window.

- **#1 (19df3db)** `sr-writing-plans` Task Structure template uses a
  4-backtick outer fence with clean inner triple-backticks,
  replacing the backslash-escaped 3-backtick version.
- **#2 (4fd9aa2)** `sr-writing-skills` frontmatter claim corrected
  to say `name` and `description` are the required fields (not the
  only ones); pointer added to
  [agentskills.io/specification](https://agentskills.io/specification).
- **A (9ccce3b)** Context-isolation paragraphs added to
  `sr-dispatching-parallel-agents`, `sr-requesting-code-review`,
  and `sr-subagent-driven-development`. Skipped sections that
  don't exist in super-ralph (sr-brainstorming spec review loop,
  sr-writing-plans plan review loop).
- **D (daa3fb2)** Architecture / escalation guidance:
  `## File Structure` in `sr-writing-plans`;
  `## Model Selection` + `## Handling Implementer Status` in
  `sr-subagent-driven-development/SKILL.md`;
  `## Code Organization` + `## When You're in Over Your Head` +
  4-status Report Format in
  `sr-subagent-driven-development/implementer-prompt.md`;
  architecture bullets appended to
  `code-quality-reviewer-prompt.md`.
- **E (d48b14e)** `sr-brainstorming` "Understanding the idea"
  bullets flag multi-subsystem scope first, decompose before
  asking detail questions. `sr-writing-plans` gets a
  `## Scope Check` backstop.
- **C (e6221a4 + 3f80f1c)** Inline self-review replaces the never-
  shipped subagent review loops. `sr-brainstorming/After the
  Design` gets a `**Spec Self-Review**` subsection;
  `sr-writing-plans` gets `## No Placeholders` and `## Self-Review`
  sections. Execution Handoff offer is intentionally preserved.
- **F (1c53f5d)** `<SUBAGENT-STOP>` block added at the top of
  `using-super-ralph/SKILL.md`.
- **G (b23c084)** `## Instruction Priority` section added to
  `using-super-ralph/SKILL.md` using sr- terminology and keeping
  super-ralph's "only when clearly relevant" philosophy — does not
  import upstream's `<EXTREMELY-IMPORTANT>` 1% rule block.

### Intentional Divergences

- **sr-executing-plans retains the 3-task batch pattern.** Upstream
  Superpowers' `3bdd66e` dropped batch-and-stop based on regression
  data. Super-Ralph keeps it because `sr-executing-plans` is the
  dedicated parallel-session fallback for harnesses without good
  subagent support; `sr-subagent-driven-development` is the
  recommended single-pass path where subagent support is available.
  Divergence documented at the top of
  `plugins/super-ralph/skills/sr-executing-plans/SKILL.md`.
- **No platform-specific tool mappings imported.** Super-Ralph
  ships as a Claude Code plugin and intentionally doesn't carry
  Codex / Gemini / Copilot `references/*-tools.md`.
- **No brainstorm-server / visual companion.** Super-Ralph is
  shell-first and doesn't ship the Node.js HTTP+WebSocket server.
- **No `<EXTREMELY-IMPORTANT>` 1% rule in `using-super-ralph`.**
  Super-Ralph deliberately invokes skills only when clearly
  relevant.

### Not ported (notes)

- Version-check / auto-update (`170c530`, `4e18943`): Super-Ralph
  has its own release cycle.
- Question-detection family (`7fb4ed7`, `d69b652`, `ffbc034`):
  requires porting `lib/response_analyzer.sh`, larger than this
  sync cycle.
- Docs-directory restructuring in Superpowers (`f57638a` etc.):
  Super-Ralph uses `docs/plans/`, intentionally not
  `docs/superpowers/`.

## [1.2.1] - 2026-02-09

### Added
- **Logging library**: Extracted `log_status()` and color constants to
  `lib/logging.sh` -- libraries auto-source it when not already available
- **Install tests**: 16 tests covering dependencies, directory structure, file
  permissions, command creation, PATH detection, and uninstall verification
- **Logging tests**: 8 tests for log levels, timestamps, file output, and color
  constants
- **Full validate_allowed_tools coverage**: 8 additional tests for MultiEdit,
  Glob, Grep, Task, TodoWrite, WebFetch, WebSearch, NotebookEdit, and all
  Bash patterns
- **Auto-detect tests**: 14 tests for detect_project_tools covering Node.js,
  Python, Rust, Go, Ruby, Elixir, PHP, .NET, Docker, Make, and lockfile variants
- **Elixir/PHP/.NET detection**: `detect_project_tools` now recognizes mix.exs,
  composer.json, and *.csproj/*.sln/global.json
- **`count_changed_files` helper**: Extracted duplicated git diff file counting
  into a reusable function
- **Makefile targets**: `make clean` (remove artifacts), `make test-file FILE=...`
  (run single test file)
- **Exit detector tests**: 36 tests for should_exit_gracefully() covering all 6
  exit conditions, priority ordering, jq parsing edge cases, and validate_ralphrc()
  with boundary values
- **TMUX utils tests**: Expanded from 3 to 12 tests covering command assembly
  for all configuration options (--calls, --prompt, --verbose, --timeout, etc.)
- **Auto-detect test expansion**: 31 tests covering Kotlin Gradle, setup.py,
  setup.cfg, uv.lock, bunfig.toml, Elixir, PHP, .NET (csproj/sln/global.json),
  docker-compose variants, and multi-language projects
- **Test deduplication**: Moved detect_project_tools and exit detection tests
  to dedicated test files, eliminating duplicated inline function definitions
- **295 bats tests** total across 13 test files

### Improved
- **Self-contained libraries**: tmux_utils.sh, session_manager.sh, and
  exit_detector.sh source logging.sh directly instead of requiring caller to
  provide `log_status()`
- **Main loop slimmed**: Removed inline color constants and log_status definition
  (now sourced from lib/logging.sh)

## [1.2.0] - 2026-02-09

### Added
- **Session Manager library**: Extracted session functions to lib/session_manager.sh
- **TMUX Utils library**: Extracted tmux monitoring to lib/tmux_utils.sh
- **Exit Detector library**: Extracted exit detection and config validation to
  lib/exit_detector.sh with `should_exit_gracefully()` and `validate_ralphrc()`
- **`make release` target**: Automated version bumping across all config files
- **Config validation**: Validates numeric values, output format, and session
  expiry after loading .ralphrc (prevents silent misconfiguration)
- **Gate source validation**: tdd_gate.sh and verification_gate.sh check
  gate_utils.sh exists before sourcing, with clear error messages
- **46 new tests**: Session manager (16), TMUX utils (3), main loop (27) covering
  validate_allowed_tools, load_ralphrc, should_exit_gracefully, validate_ralphrc
- **23 more tests**: Rate limiting (12), project setup (11) for init_call_tracking,
  can_make_call, increment_call_counter, update_status, and scaffolding validation
- **5 SKILL.md consistency tests**: Validates frontmatter fields, "Use when"
  descriptions, Related Skills sections, and sr- prefix references
- **Configurable context length**: `MAX_LOOP_CONTEXT_LENGTH` replaces hardcoded 800
- **Configurable timing constants**: `PROGRESS_CHECK_INTERVAL`, `POST_EXECUTION_PAUSE`,
  `RETRY_BACKOFF_SECONDS`, `RATE_LIMIT_RETRY_SECONDS` replace hardcoded values

- **6 stop-hook tests**: Methodology context verification (skill routing table,
  enforcement rules), system message format (promise instructions, infinite mode),
  multiline promise extraction (perl path), and --- delimiter resilience
- **8 skill selector tests**: New BUG patterns (repair, correct, hotfix, patch) and
  FEATURE patterns (enhance, extend, expand), plus whitespace-only input handling
- **1 gate_utils test**: Read permission check for unreadable files

### Improved
- **Main loop reduced**: super_ralph_loop.sh down from 1411 to 1191 lines
- **Stop-hook systemMessage**: Condensed from 25 to 8 lines
- **Install.sh**: Copies all library files during install; uninstall verifies removal
- **SKILL.md consistency**: All 14 skills now have standardized `## Related Skills`
  sections and consistent YAML frontmatter (unquoted, "Use when" prefix)
- **Lint flag sync**: Makefile shellcheck flags match CI workflow
- **CI simplified**: Workflow uses `make test`/`make lint`/`make version-check` targets
- **Skill classifier expanded**: BUG patterns now include resolve, repair, correct,
  hotfix, patch; FEATURE patterns include enhance, extend, expand
- **gate_utils hardened**: `read_lowercase()` checks file read permissions and handles
  `tr` errors gracefully

### Removed
- **Dead code**: Removed unused `SUPER_RALPH_ENABLED` from installer template

## [1.1.1] - 2026-02-09

### Added
- **Red Flags sections**: Added to all SKILL.md files missing them (sr-brainstorming,
  sr-writing-plans, sr-dispatching-parallel-agents, sr-executing-plans,
  sr-receiving-code-review, sr-writing-skills, using-super-ralph)
- **Related Skills sections**: Added cross-references to sr-brainstorming, sr-writing-plans,
  sr-dispatching-parallel-agents, sr-receiving-code-review, sr-writing-skills,
  sr-verification-before-completion
- **Quick Start guide**: Added to plugin README with common workflow examples
- **Troubleshooting table**: Added to plugin README covering common installation and
  runtime issues

### Improved
- **CI workflow**: Install bats-core from source (not outdated apt package),
  ShellCheck now fails build on errors, added version consistency check
- **Install.sh portability**: Detect Linux distro (Debian, Fedora, Arch, Alpine,
  openSUSE) and suggest appropriate package manager
- **Install.sh completeness**: Copy gate_utils.sh during installation
- **Code-quality-reviewer template**: Expanded with placeholder table and
  usage instructions
- **Root-cause-tracing**: Added bash-specific stack trace examples using
  `caller` builtin and `set -x`
- **Makefile**: Added version-check target for config file consistency

### Fixed
- **CHANGELOG dates**: Corrected year from 2025 to 2026
- **Test file listing**: Fixed test_gate_utils filename in README (was .sh, now .bats)
- **Windows symlink paths**: Fixed .codex and .opencode INSTALL.md Windows
  PowerShell commands to include plugins/super-ralph/ path segment
- **skill_selector.sh**: Empty input now returns UNKNOWN (was silently defaulting
  to PLAN_TASK)
- **gate_utils.sh**: Replaced useless `cat | tr` with `tr < file`
- **stop-hook.sh**: Validate frontmatter is non-empty before parsing fields
- **Version sync**: marketplace.json and plugin.json now consistent at 1.1.1
- **Test count**: Updated from 94 to 114 in README

## [1.1.0] - 2026-02-09

### Added
- **Test suite**: 114 bats tests across 6 test files covering all gate libraries,
  stop-hook controller, shared utilities, and project auto-detection
- **Project type auto-detection**: Automatically configures allowed tools based on
  project files (package.json, Cargo.toml, pyproject.toml, go.mod, Gemfile, etc.)
- **Shared gate utilities** (`lib/gate_utils.sh`): Extracted common pattern matching
  and JSON building functions to reduce code duplication
- **GitHub Actions CI**: Automated testing on macOS and Linux with ShellCheck linting
- **CONTRIBUTING.md**: Development setup, architecture overview, testing guidelines
- **CHANGELOG.md**: Version history documentation
- **Makefile**: Targets for test, lint, install, uninstall, check
- Pure bash fallback for `<promise>` tag extraction when perl is unavailable

### Fixed
- **Security**: Command injection in tdd_gate.sh and verification_gate.sh via unsafe
  `jq` string interpolation — now uses `jq --arg` for safe parameter passing
- **Octal arithmetic bug**: Rate limit wait calculation failed for minutes 08/09 due
  to bash octal interpretation — now uses `10#$var` prefix
- **Datetime fallback**: `get_next_hour_time` third fallback returned current time
  instead of next hour — now correctly calculates next hour
- **Install script**: Referenced non-existent SKILL.md and wrong path for
  ralph-skill-hooks.md — corrected to actual file locations
- **Task classification**: Added word boundaries (`\b`) to prevent false positives
  (e.g., "completely" matching COMPLETION, "tissue" matching BUG "issue")
- **ShellCheck warnings**: Fixed unquoted command substitution, useless echo, read
  without -r, and declare-and-assign issues across all bash scripts
- Stop-hook sed exit code now checked; state file update verified after write

### Improved
- **TDD gate patterns**: Added word boundaries, support for more verb forms (writing,
  skipping, testing), new violation patterns (without tests, don't need test)
- **Verification gate patterns**: Support for passed/passing forms, exit code with
  colon separator, more evidence formats (ran N tests, ok N tests)
- **Live log efficiency**: Uses `tail -c 50000` instead of full file copy during
  progress monitoring
- **Configurable thresholds**: `MAX_CONSECUTIVE_TEST_LOOPS` and
  `MAX_CONSECUTIVE_DONE_SIGNALS` now configurable via .ralphrc
- **File locking**: Call counter uses flock for atomic operations with graceful
  macOS fallback
- **Setup script**: Generated .ralphrc uses auto-detected tools instead of hardcoded
  restrictive defaults
- **Stop-hook diagnostics**: Better debug logging for jq parse failures, sed errors,
  and promise extraction

## [1.0.0] - 2026-02-08

### Added
- Initial release combining Ralph autonomous loop with Superpowers methodology
- 14 sr-prefixed skills covering full development lifecycle
- Stop-hook for self-referential loop pattern
- Standalone bash system with rate limiting, circuit breaker, session continuity
- Dual-mode operation (with/without Ralph installed)
- 3 Claude Code commands: using-super-ralph, sr-cancel-ralph, sr-help
- Support for Claude Code, Codex, and OpenCode platforms
