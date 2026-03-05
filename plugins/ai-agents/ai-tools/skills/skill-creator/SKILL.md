---
name: skill-creator
description: Guide for creating effective skills. Use when creating a new skill or updating an existing skill that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.
---

# Skill Creator

Help the user create effective Claude Code skills by following this process.

## Core Principles

### Concise is Key
- Context window is a shared resource
- Assume Claude is already very smart - only add context Claude doesn't have
- Prefer concise examples over verbose explanations
- Keep SKILL.md under 500 lines; move detailed info to reference files

### Set Appropriate Degrees of Freedom
- **High freedom** (text-based): Multiple approaches valid, context-dependent
- **Medium freedom** (pseudocode/scripts): Preferred pattern exists, some variation acceptable
- **Low freedom** (specific scripts): Operations fragile, consistency critical

## Skill Anatomy

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (required: name, description)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/     - Executable code (Python/Bash/etc.)
    ├── references/  - Documentation loaded as needed
    └── assets/      - Files used in output (templates, etc.)
```

## Skill Creation Process

### Step 1: Understand the Skill
Ask clarifying questions:
1. What should this skill do? (specific actions/outcomes)
2. When should it trigger? (keywords, scenarios)
3. What inputs does it need? (arguments, context)
4. What outputs should it produce?
5. Should user invoke it (`/skill-name`) or Claude auto-invoke it, or both?

### Step 2: Plan the Skill Contents
Based on requirements, identify:
- Reusable scripts (for deterministic operations)
- Reference docs (for detailed info Claude should access)
- Assets (templates, icons, etc.)

### Step 3: Create the Skill

**Location options:**
- Personal (all projects): `~/.claude/skills/<skill-name>/SKILL.md`
- Project only: `.claude/skills/<skill-name>/SKILL.md`

**Frontmatter fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Lowercase letters, numbers, hyphens only |
| `description` | Yes | What it does AND when to use it |
| `disable-model-invocation` | No | `true` = only user can invoke |
| `user-invocable` | No | `false` = only Claude can invoke |
| `allowed-tools` | No | Tools Claude can use without permission |
| `context` | No | `fork` = run in subagent |
| `agent` | No | Subagent type when `context: fork` |

**Example SKILL.md:**

```yaml
---
name: my-skill
description: Brief description of what this does. Use when [specific triggers/scenarios].
---

Instructions for Claude when this skill is invoked.

## Steps
1. First action
2. Second action

## Additional resources
- For details, see [reference.md](references/reference.md)
```

### Step 4: Description Best Practices

The description is critical - it's how Claude decides when to use the skill.

**Good description:**
```
Comprehensive document creation and editing with support for tracked changes.
Use when working with .docx files for: creating documents, modifying content,
adding comments, or working with tracked changes.
```

**Bad description:**
```
Helps with documents.
```

Include:
- What the skill does
- Specific triggers (file types, keywords, scenarios)
- Example use cases

### Step 5: Using Arguments

Skills can receive arguments via `$ARGUMENTS` or `$0`, `$1`, etc.

```yaml
---
name: fix-issue
description: Fix a GitHub issue by number
---

Fix GitHub issue $ARGUMENTS following coding standards.
```

Invoked as: `/fix-issue 123`

### Step 6: Dynamic Context

Use ! and command to inject shell output:

```yaml
---
name: pr-summary
description: Summarize current PR
---

PR diff: <exclemation mark>`gh pr diff`
Summarize the changes above.
```

## What NOT to Include
- README.md, CHANGELOG.md, or auxiliary docs
- Info that's duplicated between SKILL.md and references
- Verbose explanations (be concise)

## References

For detailed information, consult these references:

- **[Frontmatter Reference](references/frontmatter-reference.md)** - Complete field documentation, invocation control matrix, examples
- **[Skill Patterns](references/skill-patterns.md)** - Proven design patterns, anti-patterns to avoid
- **[Arguments & Substitutions](references/arguments-and-substitutions.md)** - Variables, positional args, dynamic context injection

## Output

After creating the skill:
1. Confirm file location and how to invoke it
2. Test with a sample scenario
3. Iterate based on results