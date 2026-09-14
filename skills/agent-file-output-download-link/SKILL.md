---
name: agent-file-output-download-link
description: Use when adding a tool to a headless-claude web chat (buh-agent, lawyer-agent, logistics-agent) that PRODUCES a file for the employee — xlsx, docx, pdf. Also use for "бухгалтер не может скачать документ", "бот присылает путь на сервере", "ссылка в чате не кликается". The tool must print a /download/ link from the served directory with an ASCII name, not a server path.
---

# Файл от инструмента — ссылка /download/, не путь на сервере

**Симптом (14.09.2026, buh-agent).** Новый инструмент `pim_sellers.py` писал
готовый xlsx рядом с исходником в `data/uploads/…_продавцы.xlsx` и печатал
абсолютный путь. Бот честно отдавал его бухгалтеру, та «не могла скачать»,
владелец бегал туда-сюда. Три причины сразу:

1. `/download/<имя>` в веб-чате отдаёт файлы **только из одной папки**
   (`data/registers`), загрузки туда не входят.
2. Чат превращает в ссылку только `/download/[\w.-]+\.(docx|xlsx|pdf)` —
   в JS `\w` **не матчит кириллицу**, имя «возвраты_продавцы.xlsx» ссылкой не
   станет даже в правильной папке.
3. Промпт говорил «дай путь к файлу полностью» — бот делал ровно это.

**Правило для любого инструмента, который отдаёт файл человеку:**

```python
OUT_DIR = BASE_DIR / "data" / "registers"        # та папка, что отдаёт /download/
dst = OUT_DIR / f"prodavcy-{stamp}.xlsx"         # имя латиницей и цифрами
print(json.dumps({"ссылка": f"/download/{dst.name}", ...}, ensure_ascii=False))
```

И в системном промпте: «ссылку /download/имя.xlsx верни отдельной строкой;
путь на сервере сотруднику не нужен и не работает». Так уже сделано у
`register.py` и `table.py` — новый инструмент копирует их, а не изобретает.

**Проверка перед «готово»:** тем же путём, что сотрудник — `curl` в
`/api/chat` с файлом, вытащить ссылку из ответа, скачать её `curl -o`,
открыть openpyxl. Локальный запуск инструмента этого не ловит.
