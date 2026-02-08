#!/bin/bash

# Super-Ralph Installation Script
# Installs Super-Ralph globally, either alongside Ralph or standalone

set -e

INSTALL_DIR="$HOME/.local/bin"
SUPER_RALPH_HOME="$HOME/.super-ralph"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local color=""
    case $level in
        "INFO")    color=$BLUE ;;
        "WARN")    color=$YELLOW ;;
        "ERROR")   color=$RED ;;
        "SUCCESS") color=$GREEN ;;
    esac
    echo -e "${color}[$(date '+%H:%M:%S')] [$level] $message${NC}"
}

check_dependencies() {
    log "INFO" "Checking dependencies..."

    local missing_deps=()

    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v git &>/dev/null; then
        missing_deps+=("git")
    fi

    # Check for claude CLI
    if ! command -v claude &>/dev/null; then
        log "WARN" "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    fi

    # Check for Ralph (optional)
    if command -v ralph &>/dev/null; then
        log "INFO" "Ralph detected - Super-Ralph will run as Ralph extension"
    else
        log "INFO" "Ralph not detected - Super-Ralph will run in standalone mode"
    fi

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo "  macOS: brew install ${missing_deps[*]}"
        echo "  Linux: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi

    log "SUCCESS" "Dependencies OK"
}

install_super_ralph() {
    log "INFO" "Installing Super-Ralph..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$SUPER_RALPH_HOME"
    mkdir -p "$SUPER_RALPH_HOME/lib"
    mkdir -p "$SUPER_RALPH_HOME/templates"

    # Copy main loop script
    cp "$SCRIPT_DIR/super_ralph_loop.sh" "$SUPER_RALPH_HOME/"
    chmod +x "$SUPER_RALPH_HOME/super_ralph_loop.sh"

    # Copy library components
    cp "$SCRIPT_DIR/lib/skill_selector.sh" "$SUPER_RALPH_HOME/lib/"
    cp "$SCRIPT_DIR/lib/tdd_gate.sh" "$SUPER_RALPH_HOME/lib/"
    cp "$SCRIPT_DIR/lib/verification_gate.sh" "$SUPER_RALPH_HOME/lib/"
    chmod +x "$SUPER_RALPH_HOME/lib/"*.sh

    # Copy templates
    cp "$SCRIPT_DIR/super-ralph-prompt.md" "$SUPER_RALPH_HOME/templates/PROMPT.md"

    # Copy docs (relative to repo root, not script dir)
    local repo_dir
    repo_dir="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [[ -f "$repo_dir/docs/ralph-skill-hooks.md" ]]; then
        cp "$repo_dir/docs/ralph-skill-hooks.md" "$SUPER_RALPH_HOME/templates/"
    fi

    # Create the super-ralph command
    cat > "$INSTALL_DIR/super-ralph" << 'CMDEOF'
#!/bin/bash
SUPER_RALPH_HOME="$HOME/.super-ralph"
exec "$SUPER_RALPH_HOME/super_ralph_loop.sh" "$@"
CMDEOF
    chmod +x "$INSTALL_DIR/super-ralph"

    # Create super-ralph-setup command
    cat > "$INSTALL_DIR/super-ralph-setup" << 'CMDEOF'
#!/bin/bash
# Super-Ralph Project Setup

set -e

SUPER_RALPH_HOME="$HOME/.super-ralph"
PROJECT_NAME=${1:-"my-project"}

echo "Setting up Super-Ralph project: $PROJECT_NAME"

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

mkdir -p src
mkdir -p .ralph/{specs/stdlib,examples,logs,docs/generated}
mkdir -p docs/plans

# Copy Super-Ralph enhanced prompt
if [[ -f "$SUPER_RALPH_HOME/templates/PROMPT.md" ]]; then
    cp "$SUPER_RALPH_HOME/templates/PROMPT.md" .ralph/PROMPT.md
else
    # Fallback: create minimal prompt
    cat > .ralph/PROMPT.md << 'PROMPTEOF'
# Super-Ralph Development Instructions

## Context
You are Super-Ralph, an autonomous AI development agent with superpowers methodology.

## Methodology
Before ANY implementation:
1. Classify task: feature / bug / plan-task / completion
2. Features: brainstorm -> plan -> TDD
3. Bugs: systematic debugging (root cause first)
4. All code: test first, watch fail, implement, verify
5. Completion: run tests, read output, verify against specs

## Current Task
Follow .ralph/fix_plan.md and choose the most important uncompleted item.
PROMPTEOF
fi

# Create fix_plan.md
cat > .ralph/fix_plan.md << 'FIXEOF'
# Fix Plan

## Priority Tasks
- [ ] Define project requirements in .ralph/specs/
- [ ] Implement core feature (use TDD)
- [ ] Write comprehensive tests
- [ ] Review and verify implementation
FIXEOF

# Create AGENT.md
cat > .ralph/AGENT.md << 'AGENTEOF'
# Build and Run Instructions

## Build
<!-- Add build commands here -->

## Test
<!-- Add test commands here -->

## Run
<!-- Add run commands here -->
AGENTEOF

# Create .ralphrc
cat > .ralphrc << RCEOF
# .ralphrc - Super-Ralph project configuration
PROJECT_NAME="${PROJECT_NAME}"
MAX_CALLS_PER_HOUR=100
CLAUDE_TIMEOUT_MINUTES=15
CLAUDE_OUTPUT_FORMAT="json"
# ALLOWED_TOOLS is auto-detected from project files (package.json, Cargo.toml, etc.)
# Uncomment and customize to override auto-detection:
# ALLOWED_TOOLS="Write,Read,Edit,Bash(git *),Bash(npm *),Bash(pytest),Bash(bats *)"
SESSION_CONTINUITY=true
SESSION_EXPIRY_HOURS=24
SUPER_RALPH_ENABLED=true
RCEOF

# Initialize git
if [[ ! -d ".git" ]]; then
    git init
fi
echo "# $PROJECT_NAME" > README.md
git add .
git commit -m "Initial Super-Ralph project setup"

echo ""
echo "Project $PROJECT_NAME created with Super-Ralph!"
echo ""
echo "Next steps:"
echo "  1. Edit .ralph/specs/ with your project requirements"
echo "  2. Edit .ralph/fix_plan.md with your task list"
echo "  3. Run: super-ralph --verbose"
echo "  4. Or: super-ralph --monitor (requires tmux)"
CMDEOF
    chmod +x "$INSTALL_DIR/super-ralph-setup"

    log "SUCCESS" "Super-Ralph installed to $INSTALL_DIR"
}

check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log "WARN" "$INSTALL_DIR is not in your PATH"
        echo "Add to your shell config:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    else
        log "SUCCESS" "$INSTALL_DIR is in PATH"
    fi
}

uninstall() {
    log "INFO" "Uninstalling Super-Ralph..."
    rm -f "$INSTALL_DIR/super-ralph" "$INSTALL_DIR/super-ralph-setup"
    rm -rf "$SUPER_RALPH_HOME"
    log "SUCCESS" "Super-Ralph uninstalled"
}

main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Installing Super-Ralph                              ║"
    echo "║         Superpowers-Enhanced Autonomous Development          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_dependencies
    install_super_ralph
    check_path

    echo ""
    log "SUCCESS" "Super-Ralph installed!"
    echo ""
    echo "Commands:"
    echo "  super-ralph --help         # Show options"
    echo "  super-ralph-setup my-proj  # Create new project"
    echo "  super-ralph --verbose      # Start loop with verbose output"
    echo "  super-ralph --monitor      # Start with tmux monitoring"
    echo "  super-ralph --status       # Check current status"
    echo ""
}

case "${1:-install}" in
    install) main ;;
    uninstall) uninstall ;;
    --help|-h)
        echo "Usage: $0 [install|uninstall]"
        ;;
    *) echo "Unknown: $1"; exit 1 ;;
esac
