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

## Window stuck at 80x24, dots around the content

Symptom: the terminal is wide, but the session is drawn in a small box and the
rest of the screen is filled with `.` characters. Looks like a font or
resolution problem in VS Code — it is neither.

tmux pads the area outside the window with dots when the window is smaller
than the client. Two causes, check both:

```bash
tmux list-clients -F '#{client_tty} #{client_width}x#{client_height} -> #{client_session}'
tmux list-windows -a -F '#{session_name} #{window_width}x#{window_height}'
tmux show -t <session> -v window-size          # -> manual is the culprit
```

- **Several clients on one session.** tmux sizes the window to the *smallest*
  one, so a forgotten small SSH window shrinks the VS Code tab. Detach the
  strays: `tmux detach-client -a -t <session>`, or attach with `tmux attach -d`.
- **`window-size manual` on the session** (global default is `latest`). In
  manual mode tmux never follows the client, so a session created detached
  keeps `default-size`, i.e. 80x24, forever. **Running `tmux resize-window`
  sets `manual` as a side effect** — that is how sessions end up in this state
  without anyone choosing it.

Fix — drop the session-local option so it inherits the global `latest`:

```bash
tmux set -u -t <session> window-size
tmux refresh-client -S
```

Do NOT "fix" it with `tmux resize-window -A`: that re-arms `manual` and the
problem comes back on the next resize. Caught 04.09.2026 on three sessions at
once (`claude2`, `ozon`, `remote`) — window 80x24 inside a 353x35 terminal.

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

## RemoteCommand в ~/.ssh/config ломает Remote-SSH

Привычный для tmux хост:

```
Host myserver
    RequestTTY yes
    RemoteCommand tmux new -A -s main
```

работает для `ssh myserver`, но VS Code Remote-SSH на нём падает с
`Resolver error: Error` — без текста причины. Со стороны сервера при этом
видно `Accepted publickey`, а следом мгновенный disconnect: авторизация
проходит, спотыкается уже резолвер.

Лечится двумя хостами на один адрес — чистый для VS Code, с
`RemoteCommand` для ручного `ssh`. Автозапуск tmux в VS Code и так делает
задача `folderOpen`, так что дублировать его в конфиге незачем.

Второй источник того же `Resolver error` — дубль блока `Host` в конфиге.
`ssh` берёт первое совпадение и молчит, парсер VS Code — нет. Симптом
неотличим, так что проверяй на дубли до того, как копать логи.

## Разрывы из-за NAT

Простаивающая SSH-сессия молча выпадает: роутер выкидывает TCP без
трафика, и ни клиент, ни sshd ничего не пишут в лог — disconnect
отсутствует с обеих сторон. Признак именно этой причины, а не сетевого
сбоя.

Обе половины keepalive нужны, одной мало:

```
# /etc/ssh/sshd_config.d/60-keepalive.conf
ClientAliveInterval 30
ClientAliveCountMax 3
TCPKeepAlive yes
```

```
# ~/.ssh/config на клиенте
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Разрыв всё равно не потеря: tmux держит сессию, а в VS Code возврат — клик
по строке `<folder> [SSH: <host>]` в разделе Recent на стартовом экране,
она подключается и открывает папку разом.

## Правка конфига на Windows

Блокнот и вставка в PowerShell — главный источник поломок: `config.txt`
вместо `config`, подставленные плейсхолдеры вроде `C:\Users\ВашеИмя\`,
дубли блоков от повторной вставки. Надёжнее перезаписать файл целиком
одной строкой, которую пользователь вставляет правым кликом:

```powershell
@('Host myserver','    HostName 1.2.3.4','    User root') | Set-Content $env:USERPROFILE\.ssh\config
```

Если человеку тяжело копировать из терминала агента — отправь команду
через Telegram-бота: там блок кода копируется одним тапом.
