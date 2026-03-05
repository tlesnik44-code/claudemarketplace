# Agent Rule Formats

How to convert SKILL.md content to each agent's native rule format.

## Augment

**Location:** `.augment/rules/<plugin>--<skill>.md`
**Format:** Plain markdown, no frontmatter
**Limit:** 49,512 characters total across all rules

```markdown
# skill-name

description from SKILL.md

body content with Claude-specific syntax sanitized
```

## Cursor

**Location:** `.cursor/rules/<plugin>--<skill>.mdc`
**Format:** YAML frontmatter + markdown
**Limit:** None

```markdown
---
description: description from SKILL.md
alwaysApply: false
---

# skill-name

body content with Claude-specific syntax sanitized
```

## Windsurf

**Location:** `.windsurf/rules/<plugin>--<skill>.md`
**Format:** Plain markdown
**Limit:** 6,000 characters per file, 12,000 total

```markdown
# skill-name

description from SKILL.md

body content — TRUNCATED to ~5,500 chars if needed
```

If truncated, append: `<!-- Truncated for Windsurf 6K limit. Full version in marketplace plugin. -->`

## Codex (OpenAI)

**Location:** `AGENTS.md` (appended sections)
**Format:** Markdown sections
**Limit:** 32,768 characters total

```markdown
## plugin-name: skill-name

description from SKILL.md

body content with Claude-specific syntax sanitized

---
```

## File Naming Convention

Use `<plugin-name>--<skill-name>.<ext>` — double-dash separates plugin from skill to prevent collisions.

Examples:
- `esky-devops--helm-generator.md`
- `esky-dotnet--esky-central-packaging.mdc`

## Content Sanitization

Replace Claude-specific syntax during conversion:

| Pattern | Replacement |
|---------|-------------|
| `${CLAUDE_PLUGIN_ROOT}/scripts/` | `./scripts/ (from marketplace plugin)` |
| `${CLAUDE_PLUGIN_ROOT}` | `<plugin-root>` |
| `$ARGUMENTS`, `$0`-`$9` | Leave as documentation |
| `` !`command` `` dynamic context | Leave as-is (won't execute) |

## SKILL.md Field Mapping

| SKILL.md Field | Augment | Cursor | Windsurf | Codex |
|----------------|---------|--------|----------|-------|
| `name` | `# heading` | `# heading` | `# heading` | `## heading` |
| `description` | Paragraph | `description:` frontmatter | Paragraph | Paragraph |
| `disable-model-invocation` | Dropped | `alwaysApply: false` | Dropped | Dropped |
| `allowed-tools` | Dropped | Dropped | Dropped | Dropped |
| `context` / `agent` | Dropped | Dropped | Dropped | Dropped |
| Body content | As-is | As-is | Truncated to 5.5K | As-is |
| `references/` | Inlined if room | Separate `.mdc` | Skipped (6K limit) | Appended |

## Agent Feature Comparison

| Feature | Claude | Augment | Windsurf | Cursor | Codex |
|---------|--------|---------|----------|--------|-------|
| Folder-based rules | Yes | Yes | Yes | Yes | No |
| Single file | CLAUDE.md | .augment-guidelines | global_rules.md | .cursorrules | AGENTS.md |
| AI activation | Yes | Yes | Yes | Yes | No |
| Char limit | None | 49K | 12K | None | 32K |
| Plugin system | Yes | No | No | No | No |
