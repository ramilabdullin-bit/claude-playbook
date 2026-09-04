---
name: soffice-missing-writer
description: Use when headless `soffice --convert-to` fails with "Error: source file could not be loaded" — before blaming the document, its format, or a Cyrillic path. On a server the Writer package is often simply not installed, and then EVERY file fails, .docx included.
---

# soffice: "source file could not be loaded" — обычно нет пакета Writer

Симптом выглядит как проблема конкретного файла:

```
$ soffice --headless --convert-to docx --outdir /tmp "Карта партнера.doc"
Error: source file could not be loaded
```

Напрашивается: битый `.doc`, кириллица в пути, запятая в имени, старый
формат. Всё мимо.

## Проверка, которая экономит час

Подсунуть заведомо целый `.docx`:

```bash
soffice --headless --convert-to txt --outdir /tmp заведомо_рабочий.docx
```

Не грузится и он — дело не в файле. Смотреть состав пакетов:

```bash
dpkg -l | grep libreoffice
```

Типичная картина на сервере: `libreoffice-core`, `-common`, `-draw`,
`-impress` есть, а **`libreoffice-writer` нет**. Работы с текстовыми
документами при этом нет вовсе, хотя `soffice --version` бодро отвечает и
команда выглядит рабочей.

```bash
apt-get install -y libreoffice-writer
```

## Чем это опасно

Код с конвертацией `.doc` может месяцами числиться рабочим: путь срабатывает
редко, а падение выглядит как «плохой документ прислали». Поймано 04.09.2026
в `lawyer-agent`: в описании проекта значилось «старый .doc конвертирует через
LibreOffice», тесты этот путь не покрывали, и на первом же реальном `.doc`
выяснилось, что он не работал ни разу.

Мораль: путь, зависящий от внешней программы, надо проверять на живом файле
хотя бы раз, а не считать рабочим потому, что команда написана правильно.

Не путать с `Warning: failed to launch javaldx` — оно печатается всегда и
конвертации не мешает.
