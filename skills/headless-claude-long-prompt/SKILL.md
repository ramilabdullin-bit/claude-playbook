---
name: headless-claude-long-prompt
description: Use when wrapping `claude -p` in a script or web app that feeds it documents (contracts, invoices, reports) — passing the prompt as an argv element dies with "OSError: [Errno 7] Argument list too long" once the text grows. Pipe it through stdin instead.
---

# Длинный запрос в headless `claude -p` — только через стандартный ввод

```python
# ЛОЖИТСЯ на документе побольше
cmd = [CLAUDE_BIN, "-p", text, "--output-format", "json"]
subprocess.Popen(cmd, ...)
# OSError: [Errno 7] Argument list too long: '/usr/bin/claude'
```

```python
# Работает при любом размере
cmd = [CLAUDE_BIN, "-p", "--output-format", "json"]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, start_new_session=True)
stdout, stderr = proc.communicate(input=text.encode(), timeout=TIMEOUT)
```

`claude -p` без текста после флага читает запрос из stdin — поведение штатное.

## Почему это ловится поздно

Предел Linux — `MAX_ARG_STRLEN`, **128 КБ на ОДИН аргумент** (не на всю
строку; `getconf ARG_MAX` показывает другое число и вводит в заблуждение).

Русский текст в UTF-8 — два байта на букву. Значит 64 тысячи символов уже у
предела, а не 128 тысяч, как кажется по счётчику символов. Договор на 40–50
страниц проходит впритык и работает месяцами, пока к запросу не добавят ещё
пару килобайт — справку, свод правил, инструкцию. Тогда падает всё и сразу,
причём выглядит как поломка последней правки.

Поймано 04.09.2026 в `lawyer-agent`: добавили в сообщение свод позиций на
11 КБ (в UTF-8 ~20 КБ), и бот слёг целиком. Отсечка `MAX_DOC_CHARS = 120_000`
символов, стоявшая как защита «от гигантского файла», от этого не спасала —
она считает символы, а предел в байтах.

## Проверка, которая ловит регрессию без вызовов API

Подменить `subprocess.Popen` и убедиться, что размер командной строки НЕ
зависит от длины текста:

```python
sizes = []
for repeat in (1, 50_000):
    _r, seen = run_with("Пункт договора. " * repeat)
    sizes.append(sum(len(a.encode()) for a in seen["cmd"]))
assert sizes[0] == sizes[1], f"командная строка растёт с документом: {sizes}"
```

Плюс: после `-p` должен идти сразу следующий флаг, а не текст.

## Где ещё смотреть

Каркас веб-чата копируется между проектами, поэтому изъян тиражируется.
На 04.09.2026 он был в `lawyer-agent`, `buh-agent` и `logistics-agent` —
чинить надо во всех копиях сразу, иначе следующий большой документ уронит
соседа.

См. также [[headless-claude-529-overload]] и [[headless-claude-auth-expiry]] —
две другие ошибки, которые тоже выглядят как поломка своего кода.
