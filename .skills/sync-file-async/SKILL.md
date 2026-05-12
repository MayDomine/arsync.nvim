---
name: sync-file-async
description: >-
  Sync local project to remote host via rsync using arsync config.
  Use when the user asks to sync files to remote, upload project, push to
  remote, or mentions sync-file-async, 同步到远程, 同步文件, rsync上传.
---

# sync-file-async

Sync local project files to the remote host using rsync, configured by `.arsync`.

## MANDATORY: Read .arsync First

**Every time** this skill is triggered, you MUST use the Read tool to read the `.arsync` file from the workspace root as your **very first action**. Do NOT rely on any previously cached config — the file changes frequently. If `.arsync` does not exist, stop and tell the user.

## Steps

1. **Read `.arsync` file now** (use the Read tool, not cat/shell).
2. Parse config:
   - `REMOTE_HOST` = `remote_host`
   - `LOCAL_PATH` = `local_path`
   - `REMOTE_PATH` = `remote_path`
   - `REMOTE_PORT` = `remote_port` (0 means default)
   - `IGNORE_PATH` = `ignore_path` (JSON array of glob patterns)
   - `RSYNC_FLAGS` = `rsync_flags` (JSON array of extra flags)
3. Build and run the rsync command:

**Full project sync:**
```bash
rsync -var \
  -e "ssh" \
  --exclude '**/__pycache__' --exclude '.git/' \
  <additional --exclude per ignore_path entry> \
  <rsync_flags entries...> \
  <LOCAL_PATH>/ <REMOTE_HOST>:<REMOTE_PATH>/
```

**Single file sync:**
```bash
rsync -var -e "ssh" <LOCAL_PATH>/path/to/file <REMOTE_HOST>:<REMOTE_PATH>/path/to/file
```

- If `remote_port` is non-zero, use `-e "ssh -p <PORT>"`
- Include all `ignore_path` entries as separate `--exclude` flags
- Append all `rsync_flags` entries (e.g. `--max-size=100m`)

4. Show the command before running. Report the result.

## .arsync Config Reference

The `.arsync` file uses `key value` format, one per line:

```
auto_sync_up 1
local_path /Users/tachicoma/projects/myproject
remote_host myserver
remote_path /home/user/myproject
remote_port 0
rsync_flags ["--max-size=100m"]
ignore_path ["**/__pycache__", ".git/"]
backend rsync
```

## Notes

- If `auto_sync_up` is non-zero, arsync.nvim already syncs on save — agent doesn't need to sync after every edit.
- Always show the full command before executing so the user can verify.
