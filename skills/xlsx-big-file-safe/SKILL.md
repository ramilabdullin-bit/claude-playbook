---
name: xlsx-big-file-safe
description: Use BEFORE loading any .xlsx you did not create yourself (a client's/owner's workbook, a marketplace export, a bank statement) with openpyxl or pandas — and whenever such a load "takes forever", gets moved to the background after 120 s, or the server starts swapping. Also use for "разбери таблицу владельца", "сохрани цвета и форматирование из excel", "файл excel не открывается / висит", "openpyxl жрёт память". A 3.5 MB xlsx took the whole server down on 2026-09-09.
---

# Большие xlsx: как не раздуть память

## Почему xlsx на 3 МБ съедает 5 ГБ

xlsx — это zip. Внутри может лежать то, чего не видно по размеру файла:

| Что внутри | Сколько было в файле-виновнике | Что делает openpyxl в полном режиме |
|---|---|---|
| `xl/pivotCache/pivotCacheRecords*.xml` — кэш сводной таблицы | 79 МБ XML | парсит целиком в объекты → гигабайты |
| `<dimension ref="B1:P1048570">` — формат навешан на столбец до конца листа | 1 млн «строк» при 23 тыс. реальных | создаёт объекты на каждую |
| `sharedStrings.xml`, `calcChain.xml` | 3,5 МБ + 0,7 МБ | держит в памяти |

Ядро при этом не убивает процесс, а трэшит своп; см. [[memory-hang-no-oom-earlyoom]].

## Правило: сначала посмотри, потом грузи

```bash
unzip -l файл.xlsx | sort -k1 -rn | head -5      # размеры БЕЗ сжатия
grep -o '<dimension[^>]*>' <(unzip -p файл.xlsx xl/worksheets/sheet1.xml | head -c 2000)
```
Есть `pivotCache` или любой XML больше ~20 МБ → полный режим запрещён без подготовки ниже.

## Три способа, от дешёвого к дорогому

**1. Нужны только значения → `read_only=True`.** Замер на файле-виновнике:
45 МБ пик, 3 с (полный режим — сервер завис). `pandas.read_excel` под
капотом тоже openpyxl в полном режиме — ему тоже нельзя; давать
`engine="calamine"` (`pip install python-calamine`) или сначала способ 2.
```python
wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
for row in ws.iter_rows(values_only=True): ...
```
Подвох read_only: `ws.max_row` и `iter_rows()` идут до `dimension`, то
есть до миллиона пустых строк. Останавливаться по первой пустой ключевой
ячейке, а не по `max_row`.

**2. Нужны стили/заливки/ширины (то есть полный режим) → сначала
вырезать сводные.** `strip_pivot.py` рядом с этим файлом: удаляет
`xl/pivotCache/`, `xl/pivotTables/` и ссылки на них из rels,
`workbook.xml`, `[Content_Types].xml`. Замер: 173 МБ пик, 5 с, стили на
месте, лист сводной остаётся пустой вкладкой.
```bash
python3 ~/.claude/skills/xlsx-big-file-safe/strip_pivot.py in.xlsx /tmp/.../nopivot.xlsx
```
Дальше обычный `load_workbook(nopivot)`. Правленый файл владельцу
отдавать **без** сводной — предупредить, что сводную он пересоберёт сам,
или вставлять данные в его исходник через способ 3.

**3. Нужно только прочитать оформление, не править → XML напрямую.**
`unzip -p f.xlsx xl/styles.xml` (заливки в `<fills>`, форматы в
`<numFmts>`), `xl/worksheets/sheetN.xml` (атрибут `s="N"` у ячейки —
индекс в `cellXfs`). Ноль памяти, ноль зависимостей. Так и сделала
сессия buh-agent после падения.

## Страховка при любом способе

Прогонять тяжёлую загрузку под лимитом, чтобы ошибка стоила процесса,
а не сервера:
```bash
systemd-run --scope -q -p MemoryMax=2G -p MemorySwapMax=256M venv/bin/python script.py
```
Интерактивные сессии Claude на этом сервере уже стартуют через
`claude-capped` (3 ГБ на сессию) — но cron-скрипты и веб-приложения
ботов нет, им лимит ставить самим.

## Что НЕ делать

- Не «ждать ещё» команду, которую Claude Code увёл в фон после 120 с на
  загрузке xlsx. Это симптом раздувания, а не медленного диска: убить
  (`pkill -f load_workbook`) и перейти к способу 1–3.
- Не увеличивать своп «чтобы хватило» — трэшинг станет дольше, а не исчезнет.
