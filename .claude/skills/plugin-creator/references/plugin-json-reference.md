# plugin.json Schema Reference

The plugin manifest lives at `.claude-plugin/plugin.json` inside every plugin directory.

## Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Plugin identifier (kebab-case, no spaces). Becomes the namespace for commands/skills. | `"esky-deploy"` |

## Recommended Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `description` | string | Brief description shown in plugin manager | `"ArgoCD deployment automation"` |
| `version` | string | Semantic version | `"1.0.0"` |
| `author` | object | Author info (`name` required, `email` optional) | `{"name": "Esky Group"}` |

## Optional Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `homepage` | string | Plugin docs URL |
| `repository` | string | Source code repo URL |
| `license` | string | SPDX license identifier (e.g. `MIT`, `Apache-2.0`) |
| `keywords` | array | Tags for discovery and categorization |

## Component Configuration Fields

These override default directory discovery. Only use if your files are in non-standard locations.

| Field | Type | Description |
|-------|------|-------------|
| `commands` | string or array | Custom paths to command files or directories |
| `agents` | string or array | Custom paths to agent files |
| `hooks` | string or object | Hooks config or path to hooks file |
| `mcpServers` | string or object | MCP server configs or path to `.mcp.json` |
| `lspServers` | string or object | LSP server configs or path to `.lsp.json` |

## Full Example

```json
{
  "name": "esky-deploy",
  "description": "ArgoCD deployment automation for Esky .NET services",
  "version": "1.0.0",
  "author": {
    "name": "Esky Group",
    "email": "devtools@esky.com"
  },
  "homepage": "https://github.com/eskygroup/esky-ai-knowledge-base",
  "repository": "https://github.com/eskygroup/esky-ai-knowledge-base",
  "license": "MIT",
  "keywords": ["deployment", "argocd", "kubernetes", "helm", "gitops"]
}
```

## Notes

- The `name` field determines the command namespace: a plugin named `esky-deploy` with a command `setup` creates `/esky-deploy:setup`
- Use semantic versioning: MAJOR.MINOR.PATCH
- Keep `description` under 100 characters for clean display in the plugin manager
