---
name: resumed-session-ignores-new-prompt
description: Use when a headless-claude web chat bot (buh-agent, lawyer-agent, logistics-agent or a similar `claude -p --resume` wrapper) keeps giving the OLD answer after you changed its system prompt or added a tool — "бот пишет, что у него нет доступа", "я же добавил инструмент, а он не видит", "промпт поменял, ничего не изменилось". The resumed session carries its earlier answers; fingerprint the prompt and start a new session when it changes.
---

# Возобновлённая сессия не видит новый промпт

**Симптом (14.09.2026, buh-agent).** Добавили доступ к порталу и раздел в
системный промпт, перезапустили сервис. Владелец спрашивает бота «есть ли
доступ к порталу» — «нет». Прямой вызов `claude -p` в новой сессии отвечает
«да» и читает данные. Разница одна: веб-чат делает `--resume` старой сессии,
в которой бот уже трижды ответил «доступа нет», и держится за сказанное.
Перезапуск сервиса тут не помогает — сессия живёт в `data/session.json`.

**Не диагностировать «нет доступа» по ответу бота.** Сначала:

```bash
curl -s -c cj -d "password=$PW" http://127.0.0.1:PORT/login
curl -s -b cj -X POST http://127.0.0.1:PORT/api/new          # новая сессия
curl -s -b cj -H 'Content-Type: application/json' \
     -d '{"message":"…тот же вопрос…"}' http://127.0.0.1:PORT/api/chat
```

Если в новой сессии работает — проблема не в доступе, а в возобновлении.

**Починка раз и навсегда — отпечаток промпта** (в buh-agent и lawyer-agent
уже есть, копировать оттуда):

```python
def prompt_fingerprint() -> str:
    return hashlib.sha256(SYSTEM_PROMPT.encode()).hexdigest()[:16]

def _load_session_id():
    state = _read_json(SESSION_FILE)
    if state.get("session_id") and state.get("prompt") != prompt_fingerprint():
        return None                      # промпт изменился — сессия заново
    return state.get("session_id")

def _save_session_id(session_id):
    state = _read_json(SESSION_FILE)
    state.update(session_id=session_id, prompt=prompt_fingerprint())
    ...
```

У юриста та же правка ловила ещё и падение CLI с кодом 1 при `--resume`
с изменённым промптом (03.09.2026). Цена — сотрудник теряет контекст
разговора один раз после правки промпта; это дешевле, чем бот, который
неделю отвечает по-старому.
