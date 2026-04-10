---
name: sand-box-remove
description: >
  Remove a workspace sandbox. Use when the user says /sand-box remove, wants to unsandbox a folder,
  remove workspace restrictions, or delete sandbox configuration.
---

# Sand-box Remove

Remove sandbox configuration for a folder. No hooks to unregister — just edit config files.

## Workflow

### 1. Determine target

```
/sand-box remove              → remove sandbox from current directory
/sand-box remove /some/path   → remove sandbox from specified directory
```

### 2. Remove from `~/.sand-box.json`

Read `~/.sand-box.json`, remove the folder entry from `.folders`. Write back.

### 3. Remove shared config (if exists)

If `./.sand-box.json` exists in the target folder, ask the user if they want to remove it too (it's shared/committed).

### 4. Confirm

Tell the user the sandbox is removed. If a default profile is still set, it will still fire.
