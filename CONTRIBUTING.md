# Contributing to Super-Ralph

## Development Setup

### Prerequisites

- **bash** 4.0+ (macOS ships with 3.2 — use `brew install bash`)
- **jq** for JSON processing
- **bats-core** for testing: `brew install bats-core` or `npm install -g bats`
- **perl** (optional, for completion promise matching in stop-hook)

### Running Tests

```bash
# Run all tests
bats tests/

# Run a specific test file
bats tests/test_skill_selector.bats
bats tests/test_tdd_gate.bats
bats tests/test_verification_gate.bats
bats tests/test_stop_hook.bats

# Run with verbose output
bats --verbose-run tests/
```

## Architecture

Super-Ralph has a 3-layer architecture:

### Layer 1: Infrastructure (Bash)

Located in `standalone/`:

| File | Purpose |
|------|---------|
| `super_ralph_loop.sh` | Main autonomous loop with rate limiting, execution engine |
| `lib/gate_utils.sh` | Shared pattern matching and JSON building utilities |
| `lib/skill_selector.sh` | Task classification engine |
| `lib/tdd_gate.sh` | TDD compliance enforcement |
| `lib/verification_gate.sh` | Completion claim validator |
| `lib/session_manager.sh` | Claude session persistence and expiry |
| `lib/tmux_utils.sh` | Multi-pane tmux monitoring sessions |
| `lib/exit_detector.sh` | Graceful exit detection and config validation |
| `lib/logging.sh` | Shared colored logging and file output |
| `install.sh` | Global installation script |

### Layer 2: Claude Code Plugin

Located in `plugins/super-ralph/`:

| Directory | Purpose |
|-----------|---------|
| `hooks/` | Stop hook for self-referential loop |
| `commands/` | Claude Code slash commands |
| `skills/` | 14 methodology skills (sr- prefixed) |
| `scripts/` | Setup automation |

### Layer 3: Documentation

Located in `docs/`:

| File | Purpose |
|------|---------|
| `ralph-integration-guide.md` | Architecture and setup options |
| `ralph-skill-hooks.md` | Skill selection decision tables |
| `README.claude-code.md` | Claude Code platform docs |
| `README.codex.md` | Codex platform docs |
| `README.opencode.md` | OpenCode platform docs |

## Adding a New Gate Library

1. Create `standalone/lib/your_gate.sh`
2. Source `gate_utils.sh` for shared utilities:
   ```bash
   GATE_UTILS_DIR="$(dirname "${BASH_SOURCE[0]}")"
   source "$GATE_UTILS_DIR/gate_utils.sh"
   ```
3. Define pattern arrays and use `count_pattern_matches` / `collect_pattern_details`
4. Add tests in `tests/test_your_gate.bats`
5. Source the gate in `super_ralph_loop.sh`

## Adding a New Skill

1. Create `plugins/super-ralph/skills/sr-your-skill/SKILL.md`
2. Add YAML frontmatter with metadata
3. Register in `plugins/super-ralph/.claude-plugin/plugin.json` if needed
4. Update the skill routing table in `using-super-ralph` command

## Code Style

- Use `set -u` (not `set -e`) in hooks to handle errors explicitly
- Use `jq --arg` for safe JSON string interpolation (never `"$var"` inside jq)
- Use `10#$var` for arithmetic with zero-padded numbers (prevents octal)
- Always `|| true` after grep in variable assignments that might not match
- Export functions that need to be available in subshells
- Use `BASH_SOURCE[0]` for reliable script directory detection

## Testing Guidelines

- Write bats tests for all gate libraries and hook scripts
- Use `setup()` / `teardown()` for test isolation
- Use `$BATS_TMPDIR` for temporary files
- Test both success and failure paths
- Test edge cases: empty input, missing files, corrupted state
