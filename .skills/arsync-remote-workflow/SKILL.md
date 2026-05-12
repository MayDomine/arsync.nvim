---
name: arsync-remote-workflow
description: Detect arsync project configs in repositories that contain `.arsync`, `.vim-arsync`, or when the user mentions `.vimarsync`, arsync, remote sync, 远端同步, 远端执行, `auto_sync_up`, `remote_host`, or `remote_path`. Teach the agent the line-based config format and require syncing local changes to `remote_path` before running project build/test/script commands over SSH on `remote_execute_host` or `remote_host` when `auto_sync_up` is `1`.
---

# Arsync Remote Workflow

## Use this skill when

- The current project contains `.arsync`.
- The current project contains `.vim-arsync`.
- The user mentions `.vimarsync`, `arsync`, remote sync, or remote execution.
- You are editing code locally but the runtime, build, test, or script should execute on a remote machine.

## Config discovery

1. Search upward from the current working directory for `.arsync`.
2. If `.arsync` does not exist, search for `.vim-arsync`.
3. Treat `.vimarsync` as a user spelling variant, but the alternate filename supported by this repo is `.vim-arsync`.
4. Do not edit the config file unless the user asks.

## Config file format

Arsync project config files are plain text, one key-value pair per line:

- Format: `<key><space><value>`
- Do not use `=`
- Preserve unknown keys when rewriting
- `remote_port` and `auto_sync_up` are integers
- `rsync_flags` is a JSON array
- `local_path` and `remote_path` should not end with `/`
- `ignore_paths` is normalized to `ignore_path`

Preferred write order in this repo:

1. `auto_sync_up`
2. `local_options`
3. `local_path`
4. `remote_host`
5. `remote_user`
6. `remote_options`
7. `remote_or_local`
8. `remote_path`
9. `remote_port`
10. `rsync_flags`
11. `ignore_path`
12. `backend`
13. `remote_execute_host`
14. `tmux_cmd`
15. `entrypoint`
16. `session_name`

## Standard example

```text
auto_sync_up 1
local_options -var
local_path /Users/alice/work/my-project
remote_host login.example.com
remote_user alice
remote_options -varz
remote_or_local remote
remote_path /workspace/my-project
remote_port 22
rsync_flags ["--max-size=100m"]
ignore_path [".git","node_modules","dist"]
backend rsync
remote_execute_host compute.example.com
tmux_cmd tmux new-session -A -s
entrypoint source ~/.zshrc
session_name my-project
```

## Field semantics

- `local_path`: local project root. If omitted, the plugin falls back to the current working directory.
- `remote_host`: sync destination host.
- `remote_user`: optional SSH user for sync and remote execution.
- `remote_port`: optional SSH port. `0` means "use the default SSH port".
- `remote_path`: remote project root. Sync uploads go here, and remote commands should `cd` here before running.
- `auto_sync_up`: `1` means the agent must sync local changes before remote project commands. `0` means no automatic remote-execution assumption.
- `remote_execute_host`: optional SSH host for command execution. If empty, use `remote_host`.
- `remote_options`: rsync option string used for uploads in this repo's rsync backend.
- `rsync_flags`: extra rsync flags, usually a JSON array such as `["--max-size=100m"]`.
- `ignore_path`: optional exclude list written as a bracketed string, for example `[".git","node_modules"]`.
- `backend`: usually `rsync`; this repo also contains `sftp` and `scp` backends.
- `tmux_cmd`, `entrypoint`, `session_name`: optional helpers for long-lived remote sessions.

## Agent workflow

1. Detect the arsync config before running project commands.
2. Parse the config using the rules above.
3. If `auto_sync_up != 1`, local execution is allowed unless the user explicitly asks for remote execution.
4. If `auto_sync_up == 1`:
   - Keep file edits local.
   - Before every project runtime/build/test/script command, sync local changes to `remote_path`.
   - Run the command over SSH on `remote_execute_host` when present, otherwise on `remote_host`.
   - After more local edits, sync again before the next remote command.
5. Use `remote_path` as the remote working directory for command execution.
6. If `remote_execute_host` differs from `remote_host`, assume `remote_path` is visible from the execute host through a shared filesystem. If that assumption looks unsafe, ask the user before continuing.
7. Git inspection, local search, and file editing can stay local. Environment-dependent commands should run remotely when `auto_sync_up == 1`.

## Sync template

Before a remote command, sync the local project to the remote path. Convert `ignore_path` entries into repeated `--exclude` flags.

If `remote_port` is non-zero, include `-e "ssh -p <remote_port>"`. If it is `0`, omit the port override.

```bash
rsync <remote_options> <exclude_flags...> <rsync_flags...> "<local_path>/" "<remote_user@remote_host>:<remote_path>/"
```

Template with port override:

```bash
rsync <remote_options> -e "ssh -p <remote_port>" <exclude_flags...> <rsync_flags...> "<local_path>/" "<remote_user@remote_host>:<remote_path>/"
```

## Remote execution template

Run project commands on `remote_execute_host` when set, otherwise on `remote_host`.

If `remote_port` is non-zero:

```bash
ssh -p <remote_port> <remote_user@execute_host> 'cd "<remote_path>" && <entrypoint if any> && <command>'
```

If `remote_port` is `0`:

```bash
ssh <remote_user@execute_host> 'cd "<remote_path>" && <entrypoint if any> && <command>'
```

If `entrypoint` is unset, omit it rather than leaving a broken `&&`.

## Behavioral rules

- Do not silently run project commands locally when `auto_sync_up == 1`.
- If sync fails, stop and report the failure instead of running against stale remote code.
- When the user asks to run tests, build, start a server, or execute a project script in an arsync project with `auto_sync_up 1`, treat that as a remote command unless the user explicitly asks for local execution.
- If the task only involves reading files or editing code and no command execution, syncing is not required yet.
- Prefer `remote_execute_host` for SSH execution, but keep uploads pointed at `remote_host`.
