---
name: vscode-tmux-autostart
description: Use when setting up per-project Claude Code sessions in VS Code terminal tabs that must survive a closed window or dropped SSH, or when auto-opening several tmux sessions at once on folder open. Also use for "запусти агента в отдельном окне", "чтобы сессия не терялась при закрытии терминала", "открывать несколько tmux-сессий автоматически", "VS Code task opens the wrong tmux session".
---

# Per-project tmux sessions auto-opened by VS Code

Each project gets one long-lived tmux session on the server holding a
running `claude`. VS Code terminal tabs are just viewers — close the
window, drop the SSH link, reboot the laptop: the agent keeps running.

## Create a session

```bash
tmux new -d -s <name> -c /path/to/project 'claude; exec bash'
tmux rename-window -t <name>:0 <name>
tmux set -w -t <name>:0 automatic-rename off
```

Three non-obvious bits:

- **`'claude; exec bash'`, not bare `claude`.** With a bare command, the
  moment Claude exits (`/exit`, double Ctrl+C) tmux tears down the empty
  session and the tab is gone. The trailing `exec bash` keeps the session
  alive so you can just re-run `claude --continue` in it.
- **`rename-window` + `automatic-rename off`.** Otherwise every window in
  every session is named `claude` and the status bar can't tell them apart.
- Claude asks its **folder-trust prompt** on first launch in a new
  directory. Under automation, answer it with
  `tmux send-keys -t <name> Down Enter`, then verify with
  `tmux capture-pane -p -t <name> | tail`.

## Auto-open several sessions on folder open

Two files. `~/.vscode-server/data/Machine/settings.json`:

```json
{
  "terminal.integrated.profiles.linux": {
    "tmux":      { "path": "bash", "args": ["-c", "tmux new -A -s main 'claude; exec bash'"] },
    "tmux-proj": { "path": "bash", "args": ["-c", "tmux new -A -s proj -c /path/to/proj 'claude; exec bash'"] },
    "bash":      { "path": "bash", "icon": "terminal-bash" }
  },
  "terminal.integrated.defaultProfile.linux": "tmux",
  "terminal.integrated.automationProfile.linux": { "path": "bash" },
  "terminal.integrated.enablePersistentSessions": false
}
```

`<opened folder>/.vscode/tasks.json` — one task per session, each with
`"runOptions": {"runOn": "folderOpen"}`, `"isBackground": true`,
`"problemMatcher": []` and
`"presentation": {"panel": "dedicated", "group": "claude", "reveal": "always"}`.
Command: `tmux new -A -s <name> -c <path> 'claude; exec bash'`.

**`tmux new -A`** = attach if the session exists, create otherwise. That is
what makes a reload reconnect to the *running* agents instead of spawning
duplicates.

### The two settings that make or break it

- **`automationProfile.linux: {"path": "bash"}` — the actual gotcha.**
  VS Code runs shell tasks through the *default* terminal profile. If that
  profile is itself `tmux new -A -s main …`, every task tab attaches to
  `main` and the task's own command is swallowed as input to the already
  attached session. Symptom: all tabs show the same session; the intended
  one exists but has no client (`tmux list-clients` shows N clients, all
  pointed at `main`). A plain-bash automation profile fixes it.
- **`enablePersistentSessions: false`.** VS Code restores its own terminal
  tabs on reload *on top of* the ones the tasks create, so duplicate
  attachments to the same session accumulate with each reload. tmux already
  provides the persistence; VS Code's copy of it only conflicts.

Automatic tasks need a one-time approval: on the first folder open VS Code
prompts, or `Ctrl+Shift+P` → "Tasks: Manage Automatic Tasks" → Allow.
`runOn: folderOpen` requires an **actually opened folder** — a remote
window connected with no workspace never fires the tasks.

## Verify from the server side, not by looking at the screen

```bash
tmux ls                                                        # sessions, which are (attached)
tmux list-clients -F '#{client_tty} -> #{client_session}'      # which tab shows which session
tmux list-panes -a -F '#{session_name}: pid=#{pane_pid} cmd=#{pane_current_command} cwd=#{pane_current_path}'
```

`list-clients` is the one that catches the automation-profile bug: several
clients all pointing at the same session is the signature.

## What tmux does not survive

A reboot, or `tmux kill-server` — tmux keeps sessions in memory and writes
nothing to disk. Conversations themselves survive, because Claude Code
writes its transcript to `~/.claude/projects/<slug>/<session-id>.jsonl`:

```bash
cd /path/to/project && claude --continue    # last session in this folder
claude --resume <session-id>                # a specific one
```

Useful when moving a *running* conversation into tmux without losing it:
start `tmux new -d -s main -c <cwd> 'claude --resume <session-id>; exec bash'`,
then close the old tab. The session id is in the scratchpad path of the
running session.
