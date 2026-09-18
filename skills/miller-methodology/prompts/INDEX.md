# Промпты — индекс (методология Артемия Миллера)

Библиотека готовых промптов по методологии агентной разработки Артемия
Миллера (Школа Смысло-кодинга). **Перед тем как писать промпт с нуля —
проверь здесь.** Возможно, готовое уже есть.

> Источник: репозиторий-шаблон moy-magazin (Контент-завод), скопировано
> в этот skill 2026-09-18 дословно, лицензия MIT — см. `../LICENSE`.
> В этот skill входит только раздел **methodology** (методологические
> приёмы, применимые к любому проекту). Разделы **setup** и **launch** из
> исходного репозитория — это бутстрап конкретного шаблона проекта
> (настройка окружения, деплой, приём платежей), они не универсальны и
> в skill не скопированы; таблицы ниже оставлены с пометкой «не входит
> в skill» для навигации, если понадобится смотреть оригинал.

## Как пользоваться

1. Найди в таблице задачу, которая совпадает с твоей.
2. Открой файл по ссылке — там промпт целиком.
3. Скопируй текст промпта в чат Клоду или в промпт субагента. Подставь
   свои значения в квадратные скобки `[...]` или фигурные `{...}`.
4. В конце каждого файла есть блок «Адаптация под Контент-завод» — это
   привязка к проекту-источнику (конкретный завод/продукт из moy-magazin).
   Для другого проекта его нужно перечитать и адаптировать под текущий
   проект (или просто игнорировать, если не подходит) — не выполнять
   как есть.
5. Выполняй шаги по подсказкам Клода.

Формат файла методологии: заголовок → «Когда применять» → промпт дословно
из источника → «Адаптация под завод/проект».

## Таблица — если тебе надо, возьми

### Setup / Launch — не входит в skill

Бутстрап конкретного проекта-шаблона (voice-ввод, хуки, деплой, платежи).
Не методология, не копировалось. Смотреть в исходном репозитории
moy-magazin: `prompts/setup/*.md`, `prompts/launch/*.md`.

### Methodology (методологические приёмы)

Порядок по циклу: до плана → план → код → приёмка → регулярное.

**До плана: замысел и архитектура**

| Задача | Промпт |
|---|---|
| Грилинг: интервью по одному вопросу до SPEC.md | [`methodology/grill-to-spec.md`](./methodology/grill-to-spec.md) |
| Разведка перед кодом: кто уже решал, артефакт с разделом «Рекомендация» | [`methodology/research-before-code.md`](./methodology/research-before-code.md) |
| «Докажи, что план лучший»: 2-3 способа, выбор с обоснованием | [`methodology/prove-plan.md`](./methodology/prove-plan.md) |
| Сначала архитектура: 5 вопросов, 2 варианта устройства | [`methodology/architecture-first.md`](./methodology/architecture-first.md) |
| «10 причин обосраться» + премортем «прошёл год» перед планом | [`methodology/10-reasons.md`](./methodology/10-reasons.md) |
| Премортем через субагента (из build-idea) | [`methodology/premortem-subagent.md`](./methodology/premortem-subagent.md) |
| Импорт существующего кода в `.business/` | [`methodology/import-existing-project.md`](./methodology/import-existing-project.md) |

**План**

| Задача | Промпт |
|---|---|
| План в три захода: образ результата → макет → план → 3 вопроса → чужой опыт → защита | [`methodology/plan-three-passes.md`](./methodology/plan-three-passes.md) |
| Шаблон Plan Mode «новая фича» (похожие фичи → open-source → план → самопроверка) | [`methodology/new-feature.md`](./methodology/new-feature.md) |
| Три вопроса к плану + критика тремя субагентами в новом чате | [`methodology/three-questions-to-plan.md`](./methodology/three-questions-to-plan.md) |
| Edge cases до кода: что сломается через неделю, 100x, ноль данных, гонки | [`methodology/premortem-edge-cases.md`](./methodology/premortem-edge-cases.md) |
| Цикл против подхалима: факты → прецеденты → план → «взято с потолка» | [`methodology/plan-self-check.md`](./methodology/plan-self-check.md) |
| Правки в плане на полях `> NOTE:`, «Отработай все NOTE, не реализуй» | [`methodology/notes-in-plan.md`](./methodology/notes-in-plan.md) |
| Критика плана через 3 субагента (ссылка, объединён с three-questions) | [`methodology/plan-critique.md`](./methodology/plan-critique.md) |

**Код: правила сессии**

| Задача | Промпт |
|---|---|
| Код только под задачу, а не ради кода (рамка на сессию) | [`methodology/code-only-for-task.md`](./methodology/code-only-for-task.md) |
| Guard-фраза: код только после «Реализуй фазу N по плану» | [`methodology/guard-phrase.md`](./methodology/guard-phrase.md) |
| Дисциплина контекста: правило 40%, handoff-файл перед `/clear` | [`methodology/context-discipline.md`](./methodology/context-discipline.md) |
| Не спрашивай, а рекомендуй: формат развилки А / Б | [`methodology/recommend-not-ask.md`](./methodology/recommend-not-ask.md) |
| Оркестратор: возьми план, субагенты, отметки в файле; «ты остановился» | [`methodology/orchestrator.md`](./methodology/orchestrator.md) |
| Докажи, что баг настоящий, или не трогай код | [`methodology/prove-the-bug.md`](./methodology/prove-the-bug.md) |

**Приёмка и мерж**

| Задача | Промпт |
|---|---|
| Самопроверка по спеке перед словом «готово» (файл:строка на каждый критерий) | [`methodology/self-check-before-done.md`](./methodology/self-check-before-done.md) |
| Проверка после «готово»: 5 пунктов по кругу + финальная проверка дня «да / нет» | [`methodology/done-check.md`](./methodology/done-check.md) |
| Приёмка «не отвечай сделано»: команда и вывод целиком, что вне периметра, кто вызывает | [`methodology/acceptance.md`](./methodology/acceptance.md) |
| Приёмщик с чистым контекстом, цель — опровергнуть (субагент qa-acceptor из проекта-источника) | не входит в skill — см. `.claude/agents/qa-acceptor.md` в moy-magazin |
| Судья результата (из build-idea) | [`methodology/judge.md`](./methodology/judge.md) |
| Стоп-проверка на отговорки «out of scope», «follow-up» (JSON-evaluator, Stop-хук) | [`methodology/stop-check-excuses.md`](./methodology/stop-check-excuses.md) |
| Что мы сломали: 4 проверки перед мержем ветки | [`methodology/pre-merge-check.md`](./methodology/pre-merge-check.md) |
| Для непрограммиста: пересказ сделанного без кода + аудит безопасности по 5 дырам | [`methodology/explain-and-audit.md`](./methodology/explain-and-audit.md) |

**Регулярное**

| Задача | Промпт |
|---|---|
| Постановка регулярной задачи агенту (вход, результат, плохой результат, запреты) | [`methodology/regular-task.md`](./methodology/regular-task.md) |
| Зачистка `.business/` раз в неделю + тест «мозг подключён» | [`methodology/brain-cleanup.md`](./methodology/brain-cleanup.md) |
| Планирование недели | [`methodology/weekly-planning.md`](./methodology/weekly-planning.md) |

## Правило

> «Прежде чем писать промпт с нуля — загляни в этот INDEX.»
