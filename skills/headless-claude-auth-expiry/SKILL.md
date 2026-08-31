---
name: headless-claude-auth-expiry
description: Use when a headless `claude -p` bot on this server suddenly stops answering, "зависает", or fails within seconds with an empty error — especially when several bots break at once. Also use for "бот не отвечает", "claude завершился с ошибкой" with nothing after the colon, "ты завис", or when hardening a new headless bot so this failure is visible next time. Covers the expired-OAuth failure mode and the swallowed-stdout logging bug that hides it.
---

# Headless Claude падает молча: истёкшая авторизация

## Симптом

Бот на `claude -p` перестал отвечать. В логе:

```
ERROR bot: claude завершился с ошибкой:
```

— и **пустота после двоеточия**. Падение занимает 1-3 секунды (не таймаут).
Часто ломаются сразу все headless-боты на машине, потому что авторизация
у них общая (`/root/.claude/.credentials.json`).

Это НЕ зависание и НЕ нехватка памяти. Не ищите залипший процесс и не
трогайте лок вызовов `/root/scripts/.claude_invoke.*.lock` (с 2026-08-31
свой у каждого бота) — при истёкшей авторизации процесс отрабатывает и
умирает мгновенно.

## Почему причина не видна в логе

Типовой код вызова логирует только `stderr`:

```python
if proc.returncode != 0:
    logger.error("claude завершился с ошибкой: %s", stderr.decode(errors="replace"))
    raise RuntimeError("Ошибка при обращении к Claude Code CLI.")
```

При проблеме с авторизацией CLI пишет объяснение в **stdout**, а `stderr`
остаётся пустым — и `stdout` тут же выбрасывается, потому что до
`json.loads(stdout)` код не доходит. Лог получается бесполезным.

## Диагностика

```bash
# 1. Сроки токенов. expiresAt — access (~8ч, обновляется сам),
#    refreshTokenExpiresAt — refresh (~27 дней, вот он и истекает).
jq -r '.claudeAiOauth | {expiresAt, refreshTokenExpiresAt}' /root/.claude/.credentials.json
python3 -c "
import json,datetime as dt
d=json.load(open('/root/.claude/.credentials.json'))['claudeAiOauth']
for k in ('expiresAt','refreshTokenExpiresAt'):
    print(k, dt.datetime.fromtimestamp(d[k]/1000))
"

# 2. Скорость падения: 1-3с = авторизация, минуты = таймаут/что-то другое
grep "завершился с ошибкой" bot.log | tail -5
```

Лечение — `claude` → `/login` в интерактивном терминале на сервере
(пользователю удобно набрать `! claude` прямо в сессии). После логина
перезапустить ботов: `systemctl restart <unit>`.

## Чинить, а не диагностировать заново

### 1. Не терять причину (во ВСЕХ ботах — код продублирован, не расшарен)

```python
if proc.returncode != 0:
    # CLI пишет причину и в stderr, и в stdout — только stderr часто пуст.
    details = (stderr.decode(errors="replace").strip()
               or stdout.decode(errors="replace").strip())
    logger.error("claude завершился с ошибкой (rc=%s): %.500s", proc.returncode, details)
    low = details.lower()
    if any(w in low for w in ("oauth", "login", "authenticat", "credential", "expired")):
        raise RuntimeError(
            "Авторизация Claude Code на сервере истекла — нужен повторный /login в терминале."
        )
    raise RuntimeError("Ошибка при обращении к Claude Code CLI.")
```

Найти все места: `grep -rn "завершился с ошибкой" /root/*/bot.py`.

### 2. Узнавать заранее, а не когда бот умер

Добавить в существующий `/root/scripts/server_monitor.sh` (cron каждые 5
мин, алерт в Telegram) — **не заводить отдельный крон**:

```bash
CREDS="/root/.claude/.credentials.json"
if [ ! -r "$CREDS" ]; then
    SEVERITY="CRITICAL"; REASONS+=("нет доступа к $CREDS — Claude Code не авторизован")
else
    REFRESH_EXP_MS=$(jq -r '.claudeAiOauth.refreshTokenExpiresAt // empty' "$CREDS" 2>/dev/null)
    DAYS_LEFT=$(( (REFRESH_EXP_MS / 1000 - $(date +%s)) / 86400 ))
    if [ "$DAYS_LEFT" -lt 1 ]; then
        SEVERITY="CRITICAL"; REASONS+=("авторизация Claude Code ИСТЕКЛА — нужен /login")
    elif [ "$DAYS_LEFT" -lt 3 ]; then
        [ "$SEVERITY" = "OK" ] && SEVERITY="WARNING"
        REASONS+=("авторизация Claude Code истекает через ${DAYS_LEFT} дн.")
    fi
fi
```

Плюс страховка на то, что срок годности не ловит (отозванный токен, сбой
обновления) — свежий сбой вызова в логе любого бота:

```bash
for BOTLOG in /root/*/bot.log; do
    [ -f "$BOTLOG" ] || continue
    LAST_FAIL=$(grep "claude завершился с ошибкой" "$BOTLOG" | tail -1 | awk '{print $1" "$2}' | cut -d, -f1)
    [ -n "${LAST_FAIL:-}" ] || continue
    LAST_FAIL_TS=$(date -d "$LAST_FAIL" +%s 2>/dev/null) || continue
    if [ $(( $(date +%s) - LAST_FAIL_TS )) -lt 600 ]; then
        SEVERITY="CRITICAL"
        REASONS+=("$(basename "$(dirname "$BOTLOG")") не может вызвать claude ($LAST_FAIL)")
    fi
done
```

## Грабли

- **Не сторожите `expiresAt`** (access-токен): он живёт ~8 часов и
  обновляется сам — алерт срабатывал бы трижды в сутки впустую. Сторожить
  надо `refreshTokenExpiresAt`.
- **Проверять изменения монитора на фикстуре, а не ждать реального
  истечения**: подсуньте копии скрипта файл с `refreshTokenExpiresAt` в
  прошлом и обезвредьте отправку в Telegram — иначе ветку «истекло»
  никто не проверит до следующего инцидента.
- Если формулировка алерта в скрипте была «перегрузка сервера», её надо
  обобщить — иначе придёт «перегрузка сервера — авторизация истекла».
- Родственная, но ДРУГАЯ причина падения headless-вызова под root:
  отсутствие `IS_SANDBOX=1` при `--dangerously-skip-permissions`. Тоже
  быстрый выход с ошибкой, но воспроизводится всегда, а не «вдруг через
  месяц работы».
