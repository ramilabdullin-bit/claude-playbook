# claude-playbook

Переиспользуемые skills для Claude Code на этом сервере — чтобы решения,
найденные один раз, применялись автоматически в следующий раз, а не
изобретались заново (и не сжигали токены на повторное чтение кода/CLAUDE.md
каждого проекта).

## Как это подключено

`~/.claude/skills` — симлинк на `skills/` в этом репозитории. Skills,
лежащие в `~/.claude/skills/`, доступны Claude Code глобально в любом
проекте на сервере, без привязки к конкретной рабочей директории.

## Что внутри

- `onboard-new-project` — чек-лист настройки нового проекта под Claude
  Code (CLAUDE.md, .gitignore, git init) — то, что вручную сделали для
  e-comportal, telegram-claude-bot, marketplace-agents, agents.
- `marketplace-integration-pattern` — как добавить нового клиента
  маркетплейса в `marketplace-agents` по образцу Wildberries/Ozon.
- `telegram-bot-command-pattern` — как добавить команду в
  `telegram-claude-bot`: read-only vs двухшаговый confirm-before-apply для
  мутирующих действий.
- `secret-file-guard` — как устроен и как расширять глобальный
  PreToolUse-хук, блокирующий правку `.env`/cookies/токенов.

## Добавление нового skill

`skills/<name>/SKILL.md` с frontmatter `name`/`description` — Claude сам
подхватит его после следующего перезапуска сессии (или после `/hooks`,
если менялись именно hooks, а не skills).
