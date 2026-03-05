# Arguments and String Substitutions

Skills support dynamic values through string substitution.

## Available Variables

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill |
| `$ARGUMENTS[N]` | Specific argument by 0-based index |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g., `$0`, `$1`) |
| `${CLAUDE_SESSION_ID}` | Current session ID |

## Basic Arguments

When user invokes `/fix-issue 123`, the `123` becomes `$ARGUMENTS`.

```yaml
---
name: fix-issue
description: Fix a GitHub issue by number
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

## Positional Arguments

Access specific arguments by position (0-based).

```yaml
---
name: migrate-component
description: Migrate a component from one framework to another
---

Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

Invoked as: `/migrate-component SearchBar React Vue`
- `$0` = `SearchBar`
- `$1` = `React`
- `$2` = `Vue`

Equivalent using full syntax:
- `$ARGUMENTS[0]` = `SearchBar`
- `$ARGUMENTS[1]` = `React`
- `$ARGUMENTS[2]` = `Vue`

## Session ID

Use for logging or session-specific files.

```yaml
---
name: session-logger
description: Log activity for this session
---

Log the following to logs/${CLAUDE_SESSION_ID}.log:

$ARGUMENTS
```

## Argument Hints

Show users what arguments are expected during autocomplete.

```yaml
---
name: migrate-component
description: Migrate a component between frameworks
argument-hint: [component] [from-framework] [to-framework]
---
```

## Fallback Behavior

If `$ARGUMENTS` is not present in the skill content but arguments are provided, they're appended as:

```
ARGUMENTS: <user-provided-value>
```

## Dynamic Context Injection

Use `!`command`` to run shell commands and inject their output.

```yaml
---
name: git-summary
description: Summarize recent git activity
---

## Recent commits
!`git log --oneline -10`

## Current status
!`git status --short`

## Task
Summarize what's been happening in this repo.
```

The commands run BEFORE Claude sees the prompt. Claude receives the actual output, not the commands.

### Combining with Arguments

```yaml
---
name: review-pr
description: Review a pull request by number
---

## PR #$ARGUMENTS

Diff:
!`gh pr diff $ARGUMENTS`

Comments:
!`gh pr view $ARGUMENTS --comments`

Review this PR for issues.
```