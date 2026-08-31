#!/usr/bin/env bash
# git pre-commit hook: content-based secret scan.
# Ловит секрет по СОДЕРЖИМОМУ staged-диффа, а не по имени файла — дополняет
# глобальный PreToolUse-хук в ~/.claude/settings.json (тот блокирует
# Edit/Write/Read по имени файла типа .env/cookies.json/token.json, но не
# видит секрет, вставленный прямо в код с обычным именем файла).
set -u

FAIL=0
STAGED=$(git diff --cached --name-only --diff-filter=ACM)
[ -z "$STAGED" ] && exit 0

red()    { printf "\033[31m%s\033[0m\n" "$*" >&2; }
yellow() { printf "\033[33m%s\033[0m\n" "$*" >&2; }

for file in $STAGED; do
  case "$file" in
    # Шаблоны-образцы — штатные файлы репозитория, в них по определению
    # плейсхолдеры, а не секреты. По ИМЕНИ не блокируем, но проверки по
    # СОДЕРЖИМОМУ ниже к ним всё равно применяются: если туда вставят
    # настоящий ключ, он будет пойман как в любом другом файле.
    .env.example|.env.sample|.env.template|.env.dist|\
    */.env.example|*/.env.sample|*/.env.template|*/.env.dist|\
    .env.*.example|*/.env.*.example)
      ;;
    .env|.env.*|*/.env|*/.env.*)
      red "BLOCKED: попытка закоммитить $file — секреты не должны попадать в git."
      FAIL=1
      ;;
  esac
  [ -f "$file" ] || continue

  diff=$(git diff --cached -- "$file")

  # Ключ-в-коде. Отсеиваем два класса ложных срабатываний, иначе хук ругается
  # на любой нормальный код: подстановку переменной (TOKEN="${MPSTATS_TOKEN}",
  # password: os.environ[...], {{ secret }}) и очевидные плейсхолдеры
  # (your_token_here, changeme). Слово "example" в отсев НЕ входит — оно
  # слишком общее и глушило бы настоящие находки.
  if echo "$diff" \
      | grep -iE '^\+.*(api[_-]?key|secret|password|token|bearer)\s*[:=]\s*["'"'"'][^"'"'"']{16,}' \
      | grep -ivE '["'"'"']\s*(\$\{?[A-Za-z_]|\{\{|%\(|<[A-Za-z_]|os\.environ|process\.env|System\.getenv)' \
      | grep -qivE '(your[_-]|[_-]here\b|placeholder|changeme|change[_-]me|dummy|xxxx|\.\.\.)'; then
    yellow "WARN: в $file похоже на API-ключ/пароль в коде — секреты должны жить в .env, не в коде."
    FAIL=1
  fi

  if echo "$diff" | grep -qE '^\+.*(sk-[a-zA-Z0-9]{20,}|sk_live_[a-zA-Z0-9]{16,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,}|ghp_[0-9A-Za-z]{36}|[0-9]{8,10}:AA[0-9A-Za-z_-]{33})'; then
    red "BLOCKED: в $file похоже на реальный ключ (OpenAI/Stripe/AWS/Google/Slack/GitHub/Telegram)."
    FAIL=1
  fi

  if echo "$diff" | grep -qE '^\+.*BEGIN (RSA |DSA |EC |OPENSSH |)PRIVATE KEY'; then
    red "BLOCKED: в $file похоже на приватный ключ."
    FAIL=1
  fi
done

if [ "$FAIL" = "1" ]; then
  red ""
  red "Коммит заблокирован. Если ложное срабатывание — git commit --no-verify (но сначала перепроверь диф)."
  exit 1
fi
exit 0
