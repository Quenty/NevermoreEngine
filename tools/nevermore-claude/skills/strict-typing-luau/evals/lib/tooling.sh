#!/usr/bin/env bash
# Action-scoping test: does the skill guide agents to the right action — planner only for a whole
# package, direct conversion for a single file / scoped node — and never run the eval harness as
# part of a job? Guards against single-file workers over-orchestrating now that SKILL.md surfaces
# the tooling. One batched judge call via headless `claude -p`, scored against tooling.json. ~30s.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JS="$HERE/tooling.js"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

PROMPT="$(node "$JS" prompt)"
echo "Judging $(node -e "console.log(require('$HERE/../tooling.json').cases.length)") tasks via claude -p ..."
claude -p "$PROMPT" > "$TMP" 2>/dev/null || { echo "judge call failed"; cat "$TMP"; exit 1; }
node "$JS" score "$TMP"
