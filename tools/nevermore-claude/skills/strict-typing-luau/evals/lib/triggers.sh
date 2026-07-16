#!/usr/bin/env bash
# Triggering test: does the skill's `description` fire on the right prompts and stay quiet on
# near-misses? One batched judge call via headless `claude -p`, scored against triggers.json.
# Mechanical compare, single LLM call. ~30s.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS="$HERE/triggers.js"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

PROMPT="$(node "$JS" prompt)"
echo "Judging $(node -e "console.log(require('$HERE/../triggers.json').cases.length)") prompts via claude -p ..."
claude -p "$PROMPT" > "$TMP" 2>/dev/null || { echo "judge call failed"; cat "$TMP"; exit 1; }
node "$JS" score "$TMP"
