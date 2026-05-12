---
name: check-arsync-file
description: >-
  Compare local files with remote host to detect drift.
  Use when the user asks to compare files with remote, check remote file diff,
  verify remote sync status, or mentions check-arsync-file, 对比远程文件, 文件差异.
---

# check-arsync-file

Compare local and remote files using the arsync config.

## MANDATORY: Read .arsync First

**Every time** this skill is triggered, you MUST use the Read tool to read the `.arsync` file from the workspace root as your **very first action**. Do NOT rely on any previously cached config — the file changes frequently. If `.arsync` does not exist, stop and tell the user.

## Steps

1. **Read `.arsync` file now** (use the Read tool, not cat/shell).
2. Parse config:
   - `REMOTE_EXEC_HOST` = `remote_execute_host` or `remote_host`
   - `LOCAL_PATH` = `local_path`
   - `REMOTE_PATH` = `remote_path`
3. Determine target:
   - User specifies a file → use that
   - Otherwise → use the currently open file
4. Compute remote path: replace `LOCAL_PATH` prefix with `REMOTE_PATH`
5. Fetch and compare:

**Single file:**
```bash
ssh <REMOTE_EXEC_HOST> "cat <REMOTE_FILE_PATH>"
```
Then diff the output against the local file content.

**Directory-level (dry-run):**
```bash
rsync -avnr --delete -e "ssh" <LOCAL_PATH>/ <REMOTE_HOST>:<REMOTE_PATH>/
```
The `-n` flag prevents actual transfer; it only shows what would change.

6. Report differences to the user.

## .arsync Config Reference

The `.arsync` file uses `key value` format, one per line:

```
local_path /Users/tachicoma/projects/myproject
remote_host myserver
remote_path /home/user/myproject
remote_execute_host jump-host
ignore_path ["**/__pycache__", ".git/"]
```

- `remote_host` — SSH target for rsync
- `remote_execute_host` — SSH target for commands (falls back to `remote_host`)
- `local_path` / `remote_path` — path mapping between local and remote
