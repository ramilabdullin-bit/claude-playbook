---
name: ps1-for-windows-laptop
description: Use when writing a PowerShell script on Linux to be run on a Windows laptop (sync jobs, one-off collectors sent over Telegram). A file written with a plain heredoc silently breaks — no BOM means PowerShell 5.1 reads Cyrillic as mojibake and dies before the first line runs.
---

# .ps1 с Linux на Windows-ноутбук: три ловушки

Скрипт, записанный обычным `cat > file.ps1 <<'EOF'`, на ноутбуке не
запускается. Симптом обманчив: **окно открывается и мгновенно закрывается**,
даже если внутри есть `Read-Host`, — файл не доживает до выполнения.

## 1. Метка кодировки (BOM) — обязательна

PowerShell 5.1 (`C:\Windows\System32\WindowsPowerShell\v1.0`) без BOM читает
файл как windows-1251. Вся кириллица — пути, сообщения, сравнения имён —
превращается в мусор, строковые литералы рвутся, разбор падает с
`MissingEndCurlyBrace` или просто молча.

```python
p.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
```

Проверка: `raw.startswith(b"\xef\xbb\xbf")`.

## 2. Переводы строк — CRLF

```python
text = text.replace("\r\n", "\n").replace("\n", "\r\n")
```

## 3. Скачанный из интернета файл заблокирован

Файл, пришедший через Telegram или браузер, помечается меткой
«из интернета», и PowerShell отказывается его выполнять — снова без
внятного сообщения. Два выхода:

```
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Downloads\script.ps1"
```

либо снять метку заранее:

```
powershell -Command "Unblock-File -Path $env:USERPROFILE\Downloads\script.ps1"
```

Первый проще: одна строка вместо двух шагов.

## Как запускать, чтобы видеть ошибку

`-NoExit` держит окно открытым при любом исходе — без него окно закроется
раньше, чем человек успеет прочитать красный текст:

```
powershell -NoExit -ExecutionPolicy Bypass -File "%USERPROFILE%\Downloads\script.ps1"
```

Путь в кавычках: в «Telegram Desktop» и подобных папках есть пробел.

## Чего не делать

**Не собирать однострочники с `-Command` и вложенными кавычками** для
запуска через Win+R. Разбор кавычек ломается, и человек получает
`ParserError` вместо работы. Всегда `-File` и отдельный файл.

**Не писать в команду кириллицу**: PowerShell при вставке в окно
«Выполнить» иногда съедает заглавные русские буквы, и команда портится.
Сообщения внутри файла — можно, там кодировка уже правильная.

В самом файле полезно поставить `Read-Host` последней строкой — тогда окно
дождётся человека, даже если запускать без `-NoExit`.
