---
name: sr-writing-skills
description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
---

# Writing Skills

## Overview

**Writing skills IS Test-Driven Development applied to process documentation.**

You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).

## TDD Mapping for Skills

| TDD Concept | Skill Creation |
|-------------|----------------|
| **Test case** | Pressure scenario with subagent |
| **Production code** | Skill document (SKILL.md) |
| **Test fails (RED)** | Agent violates rule without skill (baseline) |
| **Test passes (GREEN)** | Agent complies with skill present |
| **Refactor** | Close loopholes while maintaining compliance |
| **Write test first** | Run baseline scenario BEFORE writing skill |
| **Watch it fail** | Document exact rationalizations agent uses |
| **Minimal code** | Write skill addressing those specific violations |
| **Watch it pass** | Verify agent now complies |
| **Refactor cycle** | Find new rationalizations → plug → re-verify |

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

**REQUIRED BACKGROUND:** You MUST understand sr-test-driven-development before using this skill.

## What is a Skill?

A **skill** is a reference guide for proven techniques, patterns, or tools. Skills help future instances find and apply effective approaches.

**Skills are:** Reusable techniques, patterns, tools, reference guides

**Skills are NOT:** Narratives about how you solved a problem once

## When to Create a Skill

**Create when:**
- Technique wasn't intuitively obvious to you
- You'd reference this again across projects
- Pattern applies broadly (not project-specific)
- Others would benefit

**Don't create for:**
- One-off solutions
- Standard practices well-documented elsewhere
- Project-specific conventions (put in your instructions file)
- Mechanical constraints (if enforceable with regex/validation, automate it—save documentation for judgment calls)

## Skill Types

### Technique
Concrete method with steps to follow (condition-based-waiting, root-cause-tracing)

### Pattern
Way of thinking about problems (flatten-with-flags, test-invariants)

### Reference
API docs, syntax guides, tool documentation

## Directory Structure

```
skills/
  skill-name/
    SKILL.md              # Main reference (required)
    supporting-file.*     # Only if needed
```

## SKILL.md Structure

**Frontmatter (YAML):**
- Two required fields: `name` and `description` (see [agentskills.io/specification](https://agentskills.io/specification) for all supported fields)
- Max 1024 characters total
- `name`: Use letters, numbers, and hyphens only (no parentheses, special chars)
- `description`: Third-person, describes ONLY when to use (NOT what it does)
  - Start with "Use when..." to focus on triggering conditions
  - Include specific symptoms, situations, and contexts
  - **NEVER summarize the skill's process or workflow** (see SDO section for why)
  - Keep under 500 characters if possible

```markdown
---
name: skill-name
description: Use when [specific triggering conditions and symptoms]
---

# Skill Name

## Overview
What is this? Core principle in 1-2 sentences.

## When to Use
Bullet list with SYMPTOMS and use cases

## Core Pattern
Before/after code comparison

## Quick Reference
Table or bullets for scanning

## Common Mistakes
What goes wrong + fixes
```

## Skill Discovery Optimization (SDO)

**Critical for discovery:** Future agents need to FIND your skill

### Rich Description Field

**Purpose:** Your agent reads the description to decide which skills to load for a given task.

**CRITICAL: Description = When to Use, NOT What the Skill Does**

The description should ONLY describe triggering conditions. Do NOT summarize the skill's process or workflow in the description.

**Why this matters:** When a description summarizes the skill's workflow, an agent may follow the description instead of reading the full skill content. The description becomes a shortcut agents will take, and the skill body becomes documentation agents skip.

```yaml
# BAD: Summarizes workflow - agents may follow this instead of reading skill
description: Use when executing plans - dispatches subagent per task with code review between tasks

# GOOD: Just triggering conditions, no workflow summary
description: Use when executing implementation plans with independent tasks in the current session
```

### Keyword Coverage

Use words an agent would search for:
- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"

### Token Efficiency

**Problem:** Frequently-referenced skills load into every conversation. Every token counts.

**Techniques:**
- Move details to tool help (reference `--help` instead of documenting all flags)
- Use cross-references to other skills instead of repeating content
- Compress examples (20 words beats 42 words for same information)
- Don't repeat what's in cross-referenced skills

## Match the Form to the Failure

Before writing guidance, classify the baseline failure:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips/violates a rule under pressure | Prohibition + rationalization table + red flags | Soft guidance ("prefer...", "consider...") |
| Complies, but output has the wrong shape | Positive recipe or contract: state what the output IS | Prohibition list ("don't restate", "never narrate") |
| Omits a required element | Structural: REQUIRED field or slot in the template | Prose reminders near the template |
| Behavior should depend on a condition | Conditional keyed to an observable predicate | Unconditional rule + exemption clauses |

**Rules for whichever form you pick:**
- **No nuance clauses.** "Don't X unless it matters" reopens the negotiation.
- **Exemption clauses don't scope.** "This limit doesn't apply to code blocks" still suppresses code blocks.

## The Iron Law (Same as TDD)

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

This applies to NEW skills AND EDITS to existing skills.

Write skill before testing? Delete it. Start over.
Edit skill without testing? Same violation.

**No exceptions:**
- Not for "simple additions"
- Not for "just adding a section"
- Not for "documentation updates"
- Don't keep untested changes as "reference"

## RED-GREEN-REFACTOR for Skills

### RED: Write Failing Test (Baseline)
Run pressure scenario WITHOUT the skill. Document exact behavior.

### GREEN: Write Minimal Skill
Write skill that addresses those specific rationalizations. Run same scenarios WITH skill.

### REFACTOR: Close Loopholes
Agent found new rationalization? Add explicit counter. Re-test until bulletproof.

## Testing All Skill Types

Different skill types need different test approaches:

| Skill Type | Test With | Success Criteria |
|------------|-----------|------------------|
| **Discipline** (rules/requirements) | Pressure scenarios, combined pressures | Agent follows rule under maximum pressure |
| **Technique** (how-to guides) | Application scenarios, edge cases | Agent successfully applies technique |
| **Pattern** (mental models) | Recognition scenarios, counter-examples | Agent correctly identifies when/how to apply |
| **Reference** (documentation/APIs) | Retrieval scenarios, gap testing | Agent finds and correctly applies info |

## Bulletproofing Skills Against Rationalization

Skills that enforce discipline need to resist rationalization. Agents are smart and will find loopholes under pressure.

**Scope:** This toolkit is for discipline failures — an agent that knows the rule and skips it under pressure. For wrong-shaped output or omitted elements, use the forms in Match the Form to the Failure instead.

### Close Every Loophole Explicitly

Don't just state the rule - forbid specific workarounds.

### Address "Spirit vs Letter" Arguments

Add foundational principle early:
```markdown
**Violating the letter of the rules is violating the spirit of the rules.**
```

### Build Rationalization Table

List every excuse agents use and counter each one specifically.

## Skill Creation Checklist

**RED Phase:**
- [ ] Create pressure scenarios
- [ ] Run scenarios WITHOUT skill - document baseline
- [ ] Identify patterns in rationalizations/failures

**GREEN Phase:**
- [ ] Name uses only letters, numbers, hyphens
- [ ] YAML frontmatter with required `name` and `description` (see [agentskills.io/specification](https://agentskills.io/specification))
- [ ] Description starts with "Use when..."
- [ ] Clear overview with core principle
- [ ] Address specific baseline failures
- [ ] One excellent example
- [ ] Run scenarios WITH skill - verify compliance

**REFACTOR Phase:**
- [ ] Identify NEW rationalizations
- [ ] Add explicit counters
- [ ] Build rationalization table
- [ ] Create red flags list
- [ ] Re-test until bulletproof

**Deployment:**
- [ ] Commit skill to git

## Red Flags

Stop and reassess if you catch yourself:
- Writing skill content before running baseline pressure tests (TDD violation)
- Creating a skill for a one-off solution or project-specific convention
- Writing narrative ("I solved this by...") instead of reference guide format
- Skipping the refactor phase after initial tests pass
- Not documenting specific rationalizations found during testing
- Including a `description` that summarizes the skill's process instead of triggering conditions

## Related Skills

- **sr-test-driven-development**: Foundation methodology - skills follow same RED-GREEN-REFACTOR cycle
- **sr-verification-before-completion**: Verify skill works before deployment
