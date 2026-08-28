#!/usr/bin/env bash
# Grep-based red-flag scan for a third-party Claude Code skill BEFORE it's
# copied into /root/claude-playbook/skills/ or ~/.claude/skills/.
#
# Not a substitute for actually reading the files — a first pass that
# catches the known attack shapes so a human/model doesn't have to spot
# them by eye in a wall of text. Exit 1 on any hard red flag.
#
# Usage: audit-skill.sh <path-to-skill-dir-or-file>

set -uo pipefail

TARGET="${1:?usage: audit-skill.sh <skill-dir-or-file>}"
FOUND=0

if [ -d "$TARGET" ]; then
    FILES=$(find "$TARGET" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \))
else
    FILES="$TARGET"
fi

if [ -z "$FILES" ]; then
    echo "No scannable files found under $TARGET"
    exit 0
fi

echo "=== Auditing: $TARGET ==="

# 1. Lines starting with '!' inside SKILL.md body (not a shebang) — some
#    skill-loading tooling executes these immediately when the skill is
#    read, BEFORE the model ever reasons about the instruction. This is
#    the single most dangerous pattern found in the 2026 research pass
#    (Repello AI / Datadog Security Labs write-ups on malicious skills).
BANG_HITS=$(grep -n '^!' $FILES 2>/dev/null | grep -v '^\S*:1:#!')
if [ -n "$BANG_HITS" ]; then
    echo "[HARD BLOCK] Inline '!'-command(s) found — may execute on load, before any model review:"
    echo "$BANG_HITS" | sed 's/^/    /'
    FOUND=1
fi

# 2. Overly broad tool grants in frontmatter.
BASH_WILDCARD=$(grep -n 'allowed-tools:.*Bash([*])' $FILES 2>/dev/null)
if [ -n "$BASH_WILDCARD" ]; then
    echo "[WARN] Unrestricted Bash(*) requested in frontmatter:"
    echo "$BASH_WILDCARD" | sed 's/^/    /'
    FOUND=1
fi

# 3. Credential/secret-adjacent references — not proof of malice (a
#    legitimate skill about auth can mention these), but every hit is
#    worth reading in context by hand.
SECRET_REFS=$(grep -nE '\$HOME|~/\.(ssh|aws|config/gh)|\.env\b|gh auth token|api[_-]?key|credential|secret|password|bearer' $FILES 2>/dev/null)
if [ -n "$SECRET_REFS" ]; then
    echo "[WARN] Credential/secret-adjacent references (read in context, don't auto-reject):"
    echo "$SECRET_REFS" | sed 's/^/    /'
    FOUND=1
fi

# 4. Obfuscation — base64/hex decoding, common in payload smuggling.
OBFUSCATION=$(grep -nE 'base64 +-d|base64\.b64decode|atob\(|Buffer\.from\([^,]+, *["'"'"']base64|\\x[0-9a-fA-F]{2}(\\x[0-9a-fA-F]{2}){4,}' $FILES 2>/dev/null)
if [ -n "$OBFUSCATION" ]; then
    echo "[WARN] Possible obfuscated payload (base64/hex decode):"
    echo "$OBFUSCATION" | sed 's/^/    /'
    FOUND=1
fi

# 5. Outbound network calls — flag every one; cross-check the domain
#    against what the skill claims to do. A "PDF formatter" skill has no
#    business calling an unrelated telemetry/webhook domain.
NETWORK_CALLS=$(grep -nE 'curl |wget |fetch\(|requests\.(get|post)|axios\.' $FILES 2>/dev/null)
if [ -n "$NETWORK_CALLS" ]; then
    echo "[INFO] Outbound network calls — verify each domain matches the skill's stated purpose:"
    echo "$NETWORK_CALLS" | sed 's/^/    /'
fi

echo ""
if [ "$FOUND" -eq 1 ]; then
    echo "=== Result: red flags found — read every hit above in full context before installing ==="
    exit 1
else
    echo "=== Result: no hard red flags from this pass — still read SKILL.md end to end by hand ==="
    exit 0
fi
