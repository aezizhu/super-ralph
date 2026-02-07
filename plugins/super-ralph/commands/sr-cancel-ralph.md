---
description: "Cancel active Super-Ralph Loop"
allowed-tools: ["Bash(test -f .claude/super-ralph-loop.local.md:*)", "Bash(rm .claude/super-ralph-loop.local.md)", "Read(.claude/super-ralph-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Super-Ralph

To cancel the Super-Ralph loop:

1. Check if `.claude/super-ralph-loop.local.md` exists using Bash: `test -f .claude/super-ralph-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Super-Ralph loop found."

3. **If EXISTS**:
   - Read `.claude/super-ralph-loop.local.md` to get the current iteration number from the `iteration:` field
   - Remove the file using Bash: `rm .claude/super-ralph-loop.local.md`
   - Report: "Cancelled Super-Ralph loop (was at iteration N)" where N is the iteration value
