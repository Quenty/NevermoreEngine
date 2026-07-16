#!/usr/bin/env bash
# Shared runner for the three LLM-judged skill tests (triggers / tooling / parallelism). Each builds
# ONE batched judge prompt with <name>.js, sends it through headless `claude -p`, and scores the
# reply with the same <name>.js against <name>.json. Mechanical compare, single LLM call, ~30s.
# Invoked by run.sh — see its usage block for what each test asserts and the regression it guards.
#   judge.sh <name> [noun]     e.g. judge.sh triggers prompts
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="${1:?usage: judge.sh <triggers|tooling|parallelism> [noun]}"
NOUN="${2:-cases}"
JS="$HERE/$NAME.js"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

PROMPT="$(node "$JS" prompt)"
echo "Judging $(node -e "console.log(require('$HERE/../$NAME.json').cases.length)") $NOUN via claude -p ..."
claude -p "$PROMPT" > "$TMP" 2>/dev/null || { echo "judge call failed"; cat "$TMP"; exit 1; }
node "$JS" score "$TMP"
