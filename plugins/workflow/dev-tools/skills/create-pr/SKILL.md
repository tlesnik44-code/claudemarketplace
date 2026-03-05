---
name: create-pr
description: Create a GitHub PR with AI usage classification label. Use when creating PRs, opening pull requests, or when user says "create pr", "open pr", "make pr".
---

# Create PR with AI Usage Label

Create a GitHub PR and apply the appropriate AI usage classification label.

## Steps

1. **Prepare the PR** using standard `gh pr create` workflow:
   - Check git status and ensure changes are committed
   - Push branch if needed
   - Draft title and description based on commits

2. **ALWAYS ask the user** which AI usage label to apply. Present these options:

| Label | Meaning |
|-------|---------|
| `ai-1-no-ai` | No AI used - wrote all code manually |
| `ai-2-assisted` | AI helped (Copilot, ChatGPT), but human wrote the code |
| `ai-3-native` | AI wrote the code, human guided via prompts |
| `ai-4-full-ai` | Fully automated, human only validates outcome |

3. **Create the PR** with the selected label:
   ```bash
   gh pr create --title "..." --body "..." --label "<selected-label>"
   ```

4. Return the PR URL to the user.

## Rules

- **NEVER choose the label yourself** - always ask the user
- If the label doesn't exist in the repo, create it first with `gh label create`
- Use the label format exactly: `ai-1-no-ai`, `ai-2-assisted`, `ai-3-native`, or `ai-4-full-ai`
