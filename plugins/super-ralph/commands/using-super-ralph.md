---
description: "Start Super-Ralph: autonomous loop + disciplined methodology"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
---

# Super-Ralph

Execute the setup script to initialize the Super-Ralph loop.

**IMPORTANT:** The `$ARGUMENTS` variable contains the user's raw text. It MUST be
passed as a single quoted string to prevent shell interpretation of special characters
(?, *, [], etc.) in natural language.

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" "$ARGUMENTS"
```

You are now running **Super-Ralph** — the fusion of Ralph's autonomous loop and the Superpowers engineering methodology.

## How This Works

1. You work on the task using sr- prefixed skills (see below)
2. When you try to exit, the Ralph loop feeds the SAME PROMPT back to you
3. You see your previous work in files and git history
4. You iterate and improve until the task is genuinely complete

## Skills (sr- prefix)

Use these skills when they clearly apply:

| Situation | Skill to Invoke |
|-----------|----------------|
| New feature or creative work | **sr-brainstorming** |
| Creating implementation plan | **sr-writing-plans** |
| ANY implementation work | **sr-test-driven-development** |
| Bug, error, test failure | **sr-systematic-debugging** |
| Before claiming done | **sr-verification-before-completion** |
| Independent tasks | **sr-subagent-driven-development** |
| Code review | **sr-requesting-code-review** |
| All tasks complete | **sr-finishing-a-development-branch** |

## Completion Promise

If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. The loop continues until genuine completion.
