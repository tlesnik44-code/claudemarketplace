---
name: auto-verify
description: >-
  Self-check that generated output matches user requirements. Auto-invoke AFTER
  you produce code, configs (YAML, JSON, XML), scripts, or structured output AND
  the user provided a reference example, template, explicit format rules, or
  "correct vs incorrect" comparison. Also invoke when user says /auto-verify.
---

# Auto-Verify

After generating output, compare it against user-provided requirements before
moving on. This catches structural mismatches, missing fields, and format drift.

## Trigger Conditions

Auto-run this verification when ALL of these are true:
1. You just generated or edited code/config/structured output
2. The user provided at least one of:
   - A reference example or template to follow
   - Explicit format rules ("must have", "should include", "use this structure")
   - A working example vs broken example comparison

## Verification Steps

1. **Extract constraints** from user's reference: structure, field names, nesting, format, required elements
2. **Diff against output** you just produced — check each constraint
3. **If mismatch found**: report it immediately, show expected vs actual, propose fix — do NOT silently auto-fix
4. **If all good**: state "Verified: output matches requirements" in one line and move on

## Report Format (only when issues found)

```
**Verification: issues found**
1. [Category]: description
   - Expected: `<from user reference>`
   - Actual: `<what was generated>`
   - Fix: <proposed correction>
```

## Rules

- Do NOT auto-fix — report and propose, let user decide
- Reference the specific user requirement that was violated
- If no clear requirements were provided, skip verification
- Keep the check fast — don't over-analyze trivial formatting