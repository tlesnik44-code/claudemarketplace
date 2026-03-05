# marketplace.json Reference

The marketplace catalog lives at `.claude-plugin/marketplace.json` in the repository root. It registers the repo as a Claude Code plugin marketplace.

## Our Marketplace

- **Name**: `esky-flightcontent-marketplace`
- **File**: `.claude-plugin/marketplace.json`
- **Plugin root**: `./plugins` (set via `metadata.pluginRoot`)
- **Install command**: `/plugin marketplace add eskygroup/esky-ai-knowledge-base`

## Marketplace Schema

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Marketplace identifier (kebab-case). Users see this: `/plugin install X@name` |
| `owner` | object | Maintainer info. `name` required, `email` optional |
| `plugins` | array | List of plugin entries |

### Optional Metadata

| Field | Type | Description |
|-------|------|-------------|
| `metadata.description` | string | Brief marketplace description |
| `metadata.version` | string | Marketplace version |
| `metadata.pluginRoot` | string | Base directory for relative plugin sources |

## Plugin Entry Schema

Each entry in the `plugins` array:

### Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier (must match plugin's `plugin.json` name) |
| `source` | string or object | Where to fetch the plugin from |

### Optional

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Plugin description |
| `version` | string | Plugin version |
| `author` | object | Plugin author |
| `category` | string | Category for organization |
| `tags` | array | Tags for searchability |
| `keywords` | array | Keywords for discovery |
| `homepage` | string | Documentation URL |
| `repository` | string | Source repo URL |
| `license` | string | SPDX identifier |
| `strict` | boolean | When false, marketplace entry defines plugin entirely (no plugin.json needed) |

## Source Types

### Relative path (for plugins in this repo)

```json
{
  "name": "my-plugin",
  "source": "category/my-plugin"
}
```

With `pluginRoot: "./plugins"`, this resolves to `./plugins/category/my-plugin`.

### GitHub repository (for plugins hosted elsewhere)

```json
{
  "name": "external-plugin",
  "source": {
    "source": "github",
    "repo": "owner/plugin-repo",
    "ref": "v1.0.0"
  }
}
```

### Git URL

```json
{
  "name": "gitlab-plugin",
  "source": {
    "source": "url",
    "url": "https://gitlab.com/team/plugin.git"
  }
}
```

## Adding a Plugin Entry

When creating a new plugin in this marketplace, add to the `plugins` array:

```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<category>/<plugin-name>",
  "description": "<brief description>",
  "version": "1.0.0",
  "category": "<devops|dotnet|ai-agents|workflow>",
  "tags": ["<relevant>", "<tags>"],
  "keywords": ["<search>", "<terms>"]
}
```

## Categories

Our marketplace organizes plugins into these categories:

| Category | Directory | Description |
|----------|-----------|-------------|
| `devops` | `plugins/devops/` | Deployment, CI/CD, infrastructure, Kubernetes, Helm, ArgoCD |
| `dotnet` | `plugins/dotnet/` | .NET, NuGet, C#, package management, Artifactory |
| `ai-agents` | `plugins/ai-agents/` | AI agent tools, skill management, verification |
| `workflow` | `plugins/workflow/` | Git, PRs, profiles, general development workflow |
