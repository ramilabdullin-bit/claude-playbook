#!/usr/bin/env bash
# UserPromptSubmit hook: deterministic keyword nudge toward high-value
# skills. Purely additive — never blocks the prompt (always exit 0),
# only injects a suggestion via additionalContext when a keyword/regex
# in skill-rules.json matches the prompt text. A safety net for skill
# selection relying on description-matching alone once there are many
# skills in the playbook, not a replacement for it.

set -uo pipefail

RULES_FILE="$(dirname "$0")/skill-rules.json"

input=$(cat)
prompt=$(echo "$input" | jq -r '.user_prompt // .prompt // ""' 2>/dev/null)

if [ -z "$prompt" ] || [ ! -f "$RULES_FILE" ]; then
    echo '{}'
    exit 0
fi

prompt_lc=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

matches=$(jq -r --arg p "$prompt_lc" '
  to_entries[] |
  select(.value.keywords | any(. as $k | ($p | test($k; "i")) )) |
  .key
' "$RULES_FILE" 2>/dev/null)

if [ -z "$matches" ]; then
    echo '{}'
    exit 0
fi

skill_list=$(echo "$matches" | paste -sd, - | sed 's/,/, /g')
context="[skill-rules-nudge] Keyword match against skill-rules.json — possibly relevant: ${skill_list}. Check ~/.claude/skills/<name>/SKILL.md and invoke via the Skill tool if it actually fits; this is a deterministic keyword nudge, not a determination — ignore it if it doesn't apply."

jq -n --arg ctx "$context" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
exit 0
