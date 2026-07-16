#!/usr/bin/env bash
# Execution-strategy test: does the skill tell the agent to fan out parallel sub-agents for a
# package (> ~3 files) vs convert sequentially for a single file / handful? Guards the real-use
# regression where the agent converted a whole package serially. One batched judge call via
# headless `claude -p`, scored against parallelism.json. ~30s.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS="$HERE/parallelism.js"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

PROMPT="$(node "$JS" prompt)"
echo "Judging $(node -e "console.log(require('$HERE/../parallelism.json').cases.length)") tasks via claude -p ..."
claude -p "$PROMPT" > "$TMP" 2>/dev/null || { echo "judge call failed"; cat "$TMP"; exit 1; }
node "$JS" score "$TMP"
