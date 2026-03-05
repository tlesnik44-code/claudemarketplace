# Frontmatter Reference

Complete reference for all YAML frontmatter fields in SKILL.md files.

## Required Fields

### name
- **Type:** string
- **Required:** Yes (defaults to directory name if omitted)
- **Format:** Lowercase letters, numbers, and hyphens only (max 64 characters)
- **Purpose:** Display name and `/slash-command` identifier

### description
- **Type:** string
- **Required:** Highly recommended
- **Purpose:** What the skill does AND when to use it. Claude uses this to decide when to apply the skill automatically.
- **Fallback:** If omitted, uses the first paragraph of markdown content

**Good example:**
```yaml
description: Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. Use when Claude needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks
```

**Bad example:**
```yaml
description: Helps with documents
```

## Optional Fields

### argument-hint
- **Type:** string
- **Purpose:** Hint shown during autocomplete to indicate expected arguments
- **Examples:** `[issue-number]`, `[filename] [format]`, `[component-name]`

### disable-model-invocation
- **Type:** boolean
- **Default:** `false`
- **Purpose:** When `true`, only the user can invoke the skill via `/skill-name`
- **Use cases:** Workflows with side effects like `/commit`, `/deploy`, `/send-slack-message`

### user-invocable
- **Type:** boolean
- **Default:** `true`
- **Purpose:** When `false`, hides from the `/` menu. Only Claude can invoke it.
- **Use cases:** Background knowledge that isn't actionable as a command

### allowed-tools
- **Type:** comma-separated string
- **Purpose:** Tools Claude can use without asking permission when this skill is active
- **Examples:** `Read, Grep, Glob`, `Bash(python *)`, `Read, Edit, Write`

### model
- **Type:** string
- **Purpose:** Model to use when this skill is active
- **Options:** `sonnet`, `opus`, `haiku`

### context
- **Type:** string
- **Purpose:** Execution context for the skill
- **Options:** `fork` (run in subagent)
- **Note:** When set to `fork`, the skill content becomes the subagent's prompt

### agent
- **Type:** string
- **Purpose:** Which subagent type to use when `context: fork` is set
- **Options:** `Explore`, `Plan`, `general-purpose`, or custom agent name
- **Default:** `general-purpose`

### hooks
- **Type:** object
- **Purpose:** Lifecycle hooks scoped to this skill
- **Events:** `PreToolUse`, `PostToolUse`, `Stop`

## Invocation Control Matrix

| Frontmatter | User can invoke | Claude can invoke | Context loading |
|-------------|-----------------|-------------------|-----------------|
| (default) | Yes | Yes | Description always in context |
| `disable-model-invocation: true` | Yes | No | Description not in context |
| `user-invocable: false` | No | Yes | Description always in context |

## Complete Example

```yaml
---
name: deploy-production
description: Deploy application to production environment. Use when user requests deployment, release, or push to prod.
argument-hint: [version-tag]
disable-model-invocation: true
allowed-tools: Bash(npm *), Bash(git *), Read
---

Deploy version $ARGUMENTS to production:

1. Run test suite
2. Build application
3. Tag release
4. Push to production
5. Verify deployment
```
