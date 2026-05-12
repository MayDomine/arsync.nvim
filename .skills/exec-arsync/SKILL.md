---
name: exec-arsync
description: >-
  Execute commands on the remote host configured by arsync.
  Use when the user asks to run something on remote, execute remotely,
  remote shell, or mentions exec-arsync, 远程执行, 在远端运行, 远程命令.
---

# exec-arsync

Execute commands on the remote host using the arsync config.

## MANDATORY: Read .arsync First

**Every time** this skill is triggered, you MUST use the Read tool to read the `.arsync` file from the workspace root as your **very first action**. Do NOT rely on any previously cached config — the file changes frequently. If `.arsync` does not exist, stop and tell the user.

## CRITICAL: Local Edit, Remote Execute

**ALL project code changes MUST be made locally first, then synced to remote before execution.**

The workflow is always:
1. Edit files locally (in this workspace)
2. Sync to remote via rsync (see sync-file-async skill, or run the rsync command below)
3. Then SSH to remote to execute

**NEVER** edit files directly on the remote host via SSH (e.g. `ssh host "sed ..."` or `ssh host "cat > file"`).
The remote copy is a mirror of local — direct remote edits will be overwritten on next sync.

## Sync Before Execute

Before running any command that depends on code changes, sync first:
```bash
rsync -var -e "ssh" <LOCAL_PATH>/ <REMOTE_HOST>:<REMOTE_PATH>/
```
Parse `ignore_path` from `.arsync` and add `--exclude` flags accordingly.

## Steps

1. Read `.arsync` from the workspace root. If missing, stop and tell the user.
2. Parse config:
   - `REMOTE_EXEC_HOST` = `remote_execute_host` or `remote_host`
   - `REMOTE_HOST` = `remote_host` (for rsync)
   - `REMOTE_PATH` = `remote_path`
   - `LOCAL_PATH` = `local_path`
3. If the task involves code changes: edit locally → rsync → then execute.
4. Run the user's command on remote:

**Single command:**
```bash
ssh <REMOTE_EXEC_HOST> "cd <REMOTE_PATH> && <COMMAND>"
```

**Multi-line / complex commands:**
```bash
ssh <REMOTE_EXEC_HOST> bash -c '"cd <REMOTE_PATH> && <COMMAND>"'
```

4. Show the full SSH command before executing so the user can verify.
5. Display the output and analyze results as needed.

## Common Use Cases

- Run a script: `ssh host "cd /remote/path && python train.py"`
- Check GPU status: `ssh host "nvidia-smi"`
- Inspect processes: `ssh host "ps aux | grep python"`
- Tail a log file: `ssh host "tail -100 /remote/path/logs/train.log"`
- Install dependencies: `ssh host "cd /remote/path && pip install -r requirements.txt"`

## .arsync Config Reference

The `.arsync` file uses `key value` format, one per line:

```
local_path /Users/tachicoma/projects/myproject
remote_host myserver
remote_path /home/user/myproject
remote_execute_host jump-host
session_name myproject
```

- `remote_host` — SSH target for file transfers
- `remote_execute_host` — SSH target for commands (falls back to `remote_host`)
- `remote_path` — working directory on remote

## Notes

- **Code changes → local edit → sync → remote run.** Never skip the sync step.
- Always `cd` to `remote_path` before running the command to ensure correct working directory.
- For long-running commands, warn the user about potential SSH timeout.
- If the command needs to persist beyond SSH session, suggest wrapping in tmux/nohup.
- Non-code commands (nvidia-smi, ps, tail logs, etc.) can run directly without sync.
