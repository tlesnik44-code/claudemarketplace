# Skill Design Patterns

Proven patterns for building effective skills.

## Pattern 1: High-Level Guide with References

Keep SKILL.md as navigation, move details to reference files.

```
my-skill/
├── SKILL.md (overview and quick start)
└── references/
    ├── api-reference.md
    ├── examples.md
    └── troubleshooting.md
```

**SKILL.md:**
```markdown
# PDF Processing

## Quick start
Extract text with pdfplumber:
`python scripts/extract.py input.pdf`

## Advanced features
- **Form filling**: See [forms.md](references/forms.md)
- **API reference**: See [api-reference.md](references/api-reference.md)
- **Examples**: See [examples.md](references/examples.md)
```

## Pattern 2: Domain-Specific Organization

For skills covering multiple domains, organize references by domain.

```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── references/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

## Pattern 3: Task-Based Skill with Scripts

For deterministic operations, bundle executable scripts.

```
data-export/
├── SKILL.md
└── scripts/
    ├── export_csv.py
    ├── export_json.py
    └── validate.sh
```

**SKILL.md:**
```yaml
---
name: data-export
description: Export data in various formats
allowed-tools: Bash(python *)
---

Export data using bundled scripts:
- CSV: `python scripts/export_csv.py <table>`
- JSON: `python scripts/export_json.py <table>`
```

## Pattern 4: Forked Subagent Skill

Run isolated tasks that don't pollute main context.

```yaml
---
name: deep-research
description: Research a topic thoroughly in isolation
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

## Pattern 5: Dynamic Context Injection

Inject live data before Claude sees the prompt.

```yaml
---
name: pr-summary
description: Summarize current pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Task
Summarize this pull request focusing on:
1. What changed
2. Why it changed
3. Potential issues
```

## Pattern 6: Read-Only Analysis

Restrict to read-only tools for safe exploration.

```yaml
---
name: code-reviewer
description: Review code for quality and security issues
allowed-tools: Read, Grep, Glob, Bash(git diff *)
---

Review the code and provide feedback on:
- Code clarity and readability
- Security vulnerabilities
- Performance issues
- Test coverage gaps
```

## Pattern 7: Template-Based Output

Bundle templates for consistent output.

```
report-generator/
├── SKILL.md
├── assets/
│   └── report-template.html
└── scripts/
    └── generate.py
```

## Anti-Patterns to Avoid

### Don't: Put "When to Use" in Body
The body loads AFTER triggering. Put all trigger info in description.

**Bad:**
```yaml
---
name: my-skill
description: A helpful skill
---

## When to Use This Skill
Use when you need to...
```

**Good:**
```yaml
---
name: my-skill
description: A helpful skill. Use when you need to do X, Y, or Z.
---

## Instructions
...
```

### Don't: Duplicate Information
Info should live in SKILL.md OR references, not both.

### Don't: Deep Nesting
Keep references one level deep from SKILL.md.

### Don't: Include Auxiliary Docs
No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md in skills.