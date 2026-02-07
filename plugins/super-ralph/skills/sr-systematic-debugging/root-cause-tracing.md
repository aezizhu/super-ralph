# Root Cause Tracing

## Overview

Bugs often manifest deep in the call stack. Your instinct is to fix where the error appears, but that's treating a symptom.

**Core principle:** Trace backward through the call chain until you find the original trigger, then fix at the source.

## When to Use

**Use when:**
- Error happens deep in execution (not at entry point)
- Stack trace shows long call chain
- Unclear where invalid data originated
- Need to find which test/code triggers the problem

## The Tracing Process

### 1. Observe the Symptom
Note the exact error message and location.

### 2. Find Immediate Cause
What code directly causes this error?

### 3. Ask: What Called This?
Trace one level up the call stack. What value was passed?

### 4. Keep Tracing Up
Continue asking "what called this?" until you find where the bad value originates.

### 5. Find Original Trigger
Fix at the source, not at the symptom.

## Adding Stack Traces

When you can't trace manually, add instrumentation:

```typescript
// Before the problematic operation
async function riskyOperation(input: string) {
  const stack = new Error().stack;
  console.error('DEBUG riskyOperation:', {
    input,
    cwd: process.cwd(),
    stack,
  });
  // ... proceed
}
```

**Critical:** Use `console.error()` in tests (not logger - may not show)

## Key Principle

**NEVER fix just where the error appears.** Trace back to find the original trigger.

## Stack Trace Tips

**In tests:** Use `console.error()` not logger - logger may be suppressed
**Before operation:** Log before the dangerous operation, not after it fails
**Include context:** Directory, cwd, environment variables, timestamps
**Capture stack:** `new Error().stack` shows complete call chain
