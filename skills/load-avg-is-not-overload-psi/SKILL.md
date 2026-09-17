---
name: load-avg-is-not-overload-psi
description: Use when a Linux server "перегружен" / load average is high (10+, above cores×2) but CPU is mostly idle, memory is free and there is no iowait — or when a cron load-monitor sends false CRITICAL alerts during a job that reads a network share (CIFS/SMB/NFS) or does many parallel blocking calls. Also use for "сервер перегружен, проверь что жрёт", "load 15 а всё спокойно", "монитор орёт а сервер отвечает", or when writing/reviewing any load-alert script. Diagnose via D-state THREADS, alert via /proc/pressure (PSI), not loadavg.
---

# Load average — не мера перегрузки. Алертить по PSI

## Симптом

`uptime` показывает load 10–20 на 4 ядрах, cron-монитор шлёт CRITICAL,
а при этом `top`: 85 % idle, `wa` 0, память свободна, `ps` не видит ни
одного процесса в `D`. Сервер отвечает нормально.

## Почему так

Load average = среднее число задач в состояниях **R** (runnable) **и D**
(uninterruptible sleep). Задача, ждущая ответа сетевой файловой системы
(CIFS/SMB/NFS), медленного диска или любого блокирующего syscall, сидит
в `D` и считается в load наравне с работающей. 24 потока
`ThreadPoolExecutor`, читающие SMB-шару, дают load ≈ 24 при нулевой
нагрузке на CPU.

Ловушка при диагностике: `ps -eo stat` показывает состояние только
**главного потока** процесса. Потоки в `D` видны только с `-L`.

## Диагностика (1 минута)

```bash
top -bn1 | head -5                      # idle высокий? wa = 0?
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io
ps -eLo pid,tid,stat,comm,wchan:30 | awk '$3 ~ /D/'   # ПОТОКИ в D, с wchan
mount | grep -E 'cifs|nfs|smb|sshfs'  # есть ли сетевые FS
```

Если PSI `cpu some` и `memory full` близки к нулю, а в `D` висят потоки
одного процесса с `wchan=wait_for_response` (CIFS) / `rpc_wait` (NFS) —
перегрузки нет, это ожидание сети. Процесс обычно сам заканчивается.
Убивать не нужно; при желании снизить `max_workers` у пула.

## Правильный алерт: /proc/pressure (PSI)

PSI показывает долю времени, когда задачи **реально стояли** из-за
нехватки ресурса (ядро ≥ 4.20):

| Файл | Строка | Смысл | WARNING | CRITICAL |
|---|---|---|---|---|
| `/proc/pressure/cpu` | `some avg60` | % минуты, когда кто-то ждал CPU | > 50 | > 80 |
| `/proc/pressure/memory` | `full avg60` | % минуты, когда ВСЕ стояли из-за памяти (трэшинг) | > 5 | > 25 |
| `/proc/pressure/io` | `full avg60` | то же по диску | > 20 | > 50 |

Bash-фрагмент для монитора (заменяет проверку `LOAD1 > cores*N`):

```bash
psi() { awk -v k="$1" '$1==k {for(i=2;i<=NF;i++) if($i ~ /^avg60=/){sub("avg60=","",$i); print $i}}' "/proc/pressure/$2" 2>/dev/null; }
CPU_SOME=$(psi some cpu);   CPU_SOME=${CPU_SOME:-0}
MEM_FULL=$(psi full memory); MEM_FULL=${MEM_FULL:-0}
IO_FULL=$(psi full io);      IO_FULL=${IO_FULL:-0}
gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
if gt "$CPU_SOME" 80; then SEVERITY=CRITICAL; REASONS+=("CPU: задачи ждали процессор ${CPU_SOME}% времени (load ${LOAD1})")
elif gt "$CPU_SOME" 50; then SEVERITY=WARNING; REASONS+=("CPU: ждали процессор ${CPU_SOME}% (load ${LOAD1})"); fi
# аналогично MEM_FULL 5/25, IO_FULL 20/50
```

Load average оставить в тексте алерта как справку — по нему удобно
искать виновника, но не как триггер.

## Проверка после правки (обязательно, живьём)

```bash
for i in $(seq 8); do timeout 80 sh -c 'while :; do :; done' & done   # 8 циклов на 4 ядра
sleep 65; head -1 /proc/pressure/cpu; /root/scripts/server_monitor.sh   # ждём WARNING/CRITICAL
until awk '$1=="some"{split($3,a,"=");exit !(a[2]<50)}' /proc/pressure/cpu; do sleep 5; done
/root/scripts/server_monitor.sh                                          # ждём «восстановился»
```

Обе телеграммы должны реально прийти. Грабли из практики: при замене
блока легко вырезать инициализацию `SEVERITY="OK"; REASONS=()` —
скрипт под `set -u` падает с `unbound variable` на каждом запуске cron,
и монитор молчит ровно тогда, когда нужен. После правки прогнать
руками до следующей минуты cron.

## Связанное

- `memory-hang-no-oom-earlyoom` — обратный случай: PSI memory full
  растёт, но load-монитор не успевает; там нужен earlyoom, а не порог.
- На этом сервере монитор: `/root/scripts/server_monitor.sh` (cron `*/1`),
  переведён на PSI 2026-09-17; бэкап старой версии рядом `.bak-20260917`.
