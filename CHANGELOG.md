# Changelog

All notable changes to Super-Ralph are documented in this file.

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
- **Configurable context length**: `MAX_LOOP_CONTEXT_LENGTH` replaces hardcoded 800

### Improved
- **Main loop reduced**: super_ralph_loop.sh down from 1411 to 1191 lines
- **Stop-hook systemMessage**: Condensed from 25 to 8 lines
- **Install.sh**: Copies all library files during install

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
