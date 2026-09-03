---
name: redact-secret-from-live-log
description: Use when a password, token or key has to be cut out of a log file that a RUNNING process keeps open (bot.log, app.log, service logs) — `sed -i` silently detaches the writer and the service stops logging without any error.
---

# Вырезать секрет из лога работающей службы

`sed -i` не правит файл на месте. Он пишет во временный файл и переименовывает
его поверх старого. Работающий процесс держит открытым **прежний inode** —
теперь безымянный. Дальше служба пишет в никуда: журнал выглядит замершим на
секунде правки, `systemctl is-active` показывает `active`, ошибок нет.

Поймали 03.09.2026 на `claude-file-inbox-bot`: после вырезания пароля из
`bot.log` бот работал (сообщения принимал, отвечал), но 355 строк ушли в
удалённый файл, и проверка выглядела так, будто бот вообще не получает
сообщений.

## Как проверить, что это оно

```bash
PID=$(systemctl show <служба> -p MainPID --value)
ls -l /proc/$PID/fd | grep deleted
# l-wx------ ... 3 -> /path/app.log (deleted)   <- вот оно
```

## Как достать потерянное

Пока процесс жив, файл читается через его дескриптор:

```bash
cat /proc/$PID/fd/3 | tail -n +<строка_отметки> >> /path/app.log
systemctl restart <служба>     # чтобы снова открыл настоящий файл
```

После рестарта проверь, что `(deleted)` пропал.

## Как надо было

**Проще всего — остановить, поправить, запустить:**

```bash
systemctl stop <служба>
sed -i 's/СЕКРЕТ/<вырезано>/g' app.log*
systemctl start <служба>
```

**Если останавливать нельзя** — правь, сохраняя inode (`r+` вместо
пересоздания):

```python
from pathlib import Path
p = Path("app.log")
s = p.read_text(encoding="utf-8").replace(SECRET, "<вырезано>")
with p.open("r+", encoding="utf-8") as f:
    f.write(s)
    f.truncate()
```

Строки, дописанные между чтением и записью, при этом теряются — на живом
логе это гонка. Для ротированных файлов (`app.log.1`, `.2`) её нет: их никто
не держит открытыми, там `sed -i` безопасен.

## Заодно

Резервная копия, сделанная перед правкой (`cp app.log app.log.bak`),
содержит тот же секрет. Её надо `shred -u`, иначе вырезание бессмысленно.

И причина, по которой секрет вообще попал в лог, обычно в том, что служба
логирует полный текст входящих сообщений. Стоит проверить и сказать
владельцу: секреты в такой бот слать нельзя.

См. также [[secret-file-guard]], [[git-secret-scan]].
