# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

**How to use:** Read the full template from `sr-requesting-code-review/code-reviewer.md` and fill in these placeholders before dispatching the subagent:

| Placeholder | Value |
|-------------|-------|
| `{WHAT_WAS_IMPLEMENTED}` | From implementer's report: what they built |
| `{PLAN_OR_REQUIREMENTS}` | Task N text from the implementation plan |
| `{PLAN_REFERENCE}` | Same as above or link to plan file |
| `{BASE_SHA}` | Git commit SHA before task started |
| `{HEAD_SHA}` | Current git commit SHA (after implementation) |
| `{DESCRIPTION}` | One-line task summary |

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment

**If issues found:** Dispatch implementer to fix, then re-dispatch this reviewer until clean.
