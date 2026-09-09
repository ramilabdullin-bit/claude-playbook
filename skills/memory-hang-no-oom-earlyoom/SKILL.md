---
name: memory-hang-no-oom-earlyoom
description: Use when a Linux server (VPS) "просто завис" / went unresponsive and had to be hard-rebooted, with no OOM-killer line in the journal and no alert from a cron-based load monitor — or when hardening a server that runs many memory-hungry interactive processes (Claude Code sessions, openpyxl/pandas jobs). Also use for "сервер лёг без предупреждения", "почему не пришёл алерт", "нет oom-kill в логах".
---

# Сервер завис без OOM-kill и без алерта: диагностика и earlyoom

## Симптом

Сервер перестал отвечать, помог только ребут. В `journalctl -b -1` нет
`Out of memory` / `Killed process`, последняя осмысленная строка —
`systemd-journald: Under memory pressure, flushing caches`, потом тишина.
Cron-монитор нагрузки (каждые 5 минут) ничего не прислал.

## Почему так

1. **Ядро не убивает — оно трэшит.** Пока есть своп, ядро выгружает
   страницы, а не запускает OOM-killer. Все процессы стоят в ожидании
   диска, `cron` не может даже форкнуть `curl`. OOM-killer сработал бы через
   десятки минут, ребут приходит раньше. Поэтому в журнале нет oom-kill.
2. **Опрос раз в 5 минут не ловит взрыв за 3 минуты.** Один процесс может
   съесть 4 ГБ за пару минут (у нас: `openpyxl.load_workbook` без
   `read_only` на xlsx с 79 МБ кэша сводной таблицы). В 10:40 монитор
   видел 3,7 ГБ свободных, в 10:45 уже не смог выполниться.
3. Больше свопа делает хуже: трэшинг длится дольше.

## Диагностика (5 минут)

```bash
journalctl --list-boots                       # когда оборвался прошлый boot
journalctl -b -1 -n 60 -o short-iso           # последние строки: memory pressure?
sar -r -f /var/log/sysstat/saDD -s HH:MM       # sysstat: kbavail по 10-минуткам
sar -S -q -f ...                               # своп и load — обычно ВСЁ в норме на последнем замере
# кто запустился в окне между последним нормальным замером и обрывом:
find /root/.claude/projects -name '*.jsonl' -newermt 'YYYY-MM-DD HH:MM' ! -newermt '... +10min'
# в jsonl искать tool_use Bash; типичный виновник — "moved to the background (ID ...)"
# после 120s таймаута: команда, которая уже тонула, продолжила работать в фоне.
```

## Лечение: earlyoom, а не ещё один поллер

Ловить исчерпание памяти должен демон в userspace, который убивает
самый жирный процесс ДО того, как ядро начнёт трэшить.

```bash
apt-get install -y earlyoom
cat > /etc/default/earlyoom <<'CFG'
EARLYOOM_ARGS="-m 10,5 -s 50,25 -r 0 --avoid '(^|/)(sshd|tmux|nginx|systemd|journald|dockerd|containerd)$' -N /root/scripts/earlyoom_notify.sh"
CFG
# юнит Ubuntu идёт с DynamicUser + ProtectHome — скрипт под /root не виден:
mkdir -p /etc/systemd/system/earlyoom.service.d
printf '[Service]\nDynamicUser=false\nProtectHome=false\nProtectSystem=false\n' > /etc/systemd/system/earlyoom.service.d/override.conf
systemctl daemon-reload && systemctl enable --now earlyoom && systemctl restart earlyoom
journalctl -u earlyoom -n 3     # селфтест -N должен пройти без "not executable"
```

Пороги: `-m 10,5` — SIGTERM при <10 % свободной RAM, SIGKILL при <5 %.
`-s 50,25` — своп: по умолчанию earlyoom ждёт <10 % свободного свопа, это
слишком поздно (у нас сервер висел при свопе занятом на 42 %). Условие —
И по RAM, И по свопу, поэтому холодный своп при живой RAM не триггерит.

`--avoid`: не убивать инфраструктуру. `tmux` обязательно — иначе умрёт
сервер tmux со всеми сессиями. Виновник почти всегда самый жирный по RSS,
`--prefer` не нужен.

`-N скрипт`: earlyoom экспортирует `EARLYOOM_NAME`, `EARLYOOM_PID` — скрипт
шлёт в Telegram и пишет в свой лог. Это и есть «предупреждение», которого
не было.

## Проверка (обязательно, живьём)

```bash
timeout 110 python3 -c "
import time; b=[]
for i in range(40): b.append(bytearray(200*1024*1024)); time.sleep(0.3)
print('NOT KILLED')"
journalctl -u earlyoom --since -2min | grep sending   # 'sending SIGTERM to process ... "python3"'
```
Ожидание: процесс `Terminated` при ~6,5 ГБ RSS, своп почти не тронут,
уведомление пришло. Если печатает `NOT KILLED` — пороги или юнит не те.

## Дополнительно

- Cron-монитор переводится на `*/1` — не для спасения (он не успеет), а
  чтобы был предвестник в логе.
- Корневая причина в коде: `openpyxl.load_workbook(..., read_only=True)`
  для чужих больших xlsx; стили при read_only недоступны — читать
  `xl/styles.xml`/`sheetN.xml` напрямую из zip.
