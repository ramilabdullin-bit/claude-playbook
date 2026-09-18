---
name: miller-methodology
description: Use when a task calls for one of Artemii Miller's agent-methodology prompts (Школа Смысло-кодинга): asking the owner a question with a recommendation instead of an open question, setting up a regular/cron task, grilling a task into a spec, three-pass or critiqued planning, done-check / self-check before saying «готово», acceptance that refuses «сделано» without command output, pre-merge check, premortem, context discipline (40% rule, handoff before /clear). Also use for «промпт Миллера», «спроси с рекомендацией», «recommend-not-ask», «done-check», «приёмка по Миллеру», «критика плана», «regular-task», «сформулируй регулярную задачу», «premortem». Prompts are verbatim (MIT); the per-project adaptation blocks inside refer to the owner's Контент-завод project and must be re-adapted for the current project.
---

# miller-methodology — библиотека промптов агентной разработки

Откуда это: репозиторий-шаблон **moy-magazin** (кодовое имя проекта
владельца — «Контент-завод»), папка `prompts/`. Автор методологии —
**Артемий Миллер** (Школа Смысло-кодинга). Скопировано в этот playbook
**2026-09-18** как единая точка правды: раньше промпты жили только внутри
одного шаблона-репозитория, который скоро удаляют, а нужны они везде —
ozon-agent, wb-agent, logistics-agent, leads-agent и т.д.

Копия — **дословная** (не пересказ, не переписано). Файлы не
редактировались, кроме `prompts/INDEX.md`, где поправлены ссылки на
разделы `setup/` и `launch/` (это бутстрап конкретного шаблона-проекта,
не методология — в skill не входит) и на промпт вне `prompts/`
(`qa-acceptor` — субагент из проекта-источника).

Лицензия — MIT, копирайт **Artemii Miller / Школа Смысло-кодинга**, см.
`LICENSE` в этой папке. Атрибуция важна: тексты промптов не наши.

## Как использовать

1. Открой `prompts/INDEX.md` — там таблица всех промптов по разделам
   (до плана / план / код / приёмка и мерж / регулярное).
2. Найди задачу, открой файл, скопируй текст промпта дословно в чат
   Клоду или в промпт субагента, подставь свои значения в `[...]`/`{...}`.
3. В конце каждого файла — блок «Адаптация под завод/проект»: это
   привязка к Контент-заводу (примеры, названия папок конкретного
   шаблона). Для другого проекта (Ozon, WB, логистика...) этот блок
   нужно **перечитать и адаптировать под текущий проект** или просто
   проигнорировать — выполнять как есть не надо.

## Самые ходовые промпты (шпаргалка)

| Промпт | Файл | Что делает |
|---|---|---|
| recommend-not-ask | `prompts/methodology/recommend-not-ask.md` | Не задавать открытый вопрос владельцу — предлагать развилку А/Б с рекомендацией и обоснованием |
| regular-task | `prompts/methodology/regular-task.md` | Оформить регулярную/cron-задачу агенту: вход, результат, что считать плохим результатом, запреты |
| done-check | `prompts/methodology/done-check.md` | Проверка после слова «готово»: 5 пунктов по кругу + финальная проверка дня да/нет |
| self-check-before-done | `prompts/methodology/self-check-before-done.md` | Самопроверка по спецификации до «готово»: файл:строка на каждый критерий приёмки |
| acceptance | `prompts/methodology/acceptance.md` | Приёмка «не отвечай сделано»: требует команду и вывод целиком, что вне периметра, кто именно вызывает функцию |
| stop-check-excuses | `prompts/methodology/stop-check-excuses.md` | Стоп-проверка на отговорки («out of scope», «follow-up») — JSON-evaluator, обычно Stop-хук |
| plan-critique / three-questions-to-plan | `prompts/methodology/plan-critique.md`, `.../three-questions-to-plan.md` | Критика готового плана тремя субагентами + три обязательных вопроса к плану до реализации |
| premortem-edge-cases | `prompts/methodology/premortem-edge-cases.md` | Что сломается через неделю / при 100-кратной нагрузке / без данных / при гонке — до кода |
| context-discipline | `prompts/methodology/context-discipline.md` | Правило 40% контекста + handoff-файл перед `/clear` |
| grill-to-spec | `prompts/methodology/grill-to-spec.md` | Грилинг задачи в SPEC.md интервью по одному вопросу за раз |

Полная таблица (30 промптов) — в `prompts/INDEX.md`.

## Промпт как код: stop-check-excuses уже живёт хуком

`methodology/stop-check-excuses.md` — не только текст для вставки в чат.
В `ozon-agent` и в `moy-magazin` (проект-источник) это ещё и
исполняемый **Stop-хук** — `.claude/hooks/stop-check-excuses.sh`. Промпт
в этом skill — человекочитаемый первоисточник того, что делает хук
(JSON-evaluator на отговорки вида «out of scope» / «follow-up» перед
тем, как сессия остановится). Если правишь логику хука в одном из
проектов — сверяйся с этим файлом, и наоборот.

## Кто уже ссылается на эту методологию

- `ozon-agent/rules/INDEX.md` и `ozon-agent/CLAUDE.md` §9 — ссылаются на
  приёмы этой методологии (recommend-not-ask, done-check и т.п.) как на
  часть рабочих правил агента.

Если добавляешь методологию в новый проект — ссылайся на этот skill
(`~/.claude/skills/miller-methodology/prompts/INDEX.md`), а не копируй
файлы ещё раз: одна копия на все проекты, правки — только здесь.
