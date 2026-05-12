---
name: check-arsync-log
description: >-
  SSH to remote host and capture tmux session output for inspection.
  Use when the user asks to check remote terminal output, view remote logs,
  inspect remote tmux session, or mentions check-arsync-log, 远程日志, 远程终端.
---

# check-arsync-log

Capture and display the remote tmux session output configured by arsync.

## MANDATORY: Read .arsync First

**Every time** this skill is triggered, you MUST use the Read tool to read the `.arsync` file from the workspace root as your **very first action**. Do NOT rely on any previously cached config — the file changes frequently. If `.arsync` does not exist, stop and tell the user.

## Steps

1. **Read `.arsync` file now** (use the Read tool, not cat/shell).
2. Parse config values:
   - `REMOTE_EXEC_HOST` = `remote_execute_host` field, fallback to `remote_host`
   - `SESSION_NAME` = `session_name` field, fallback to basename of `local_path`
3. Run:
   ```bash
   ssh <REMOTE_EXEC_HOST> "tmux capture-pane -Jp -S -500 -E - -t <SESSION_NAME>"
   ```
4. Display the captured output. Analyze for errors if the user asks.

## .arsync Config Reference

The `.arsync` file uses `key value` format, one per line:

```
auto_sync_up 1
local_path /Users/tachicoma/projects/myproject
remote_host myserver
remote_path /home/user/myproject
remote_execute_host jump-host
session_name myproject
```

- `remote_host` — SSH target for file transfers
- `remote_execute_host` — SSH target for commands (falls back to `remote_host`)
- `session_name` — tmux session name (falls back to basename of `local_path`)

## Troubleshooting

- `no session: <name>` → tmux session not running on remote
- Connection refused → check `remote_execute_host` / `remote_host` reachability
- Use `-S -` instead of `-S -500` for full scrollback history
