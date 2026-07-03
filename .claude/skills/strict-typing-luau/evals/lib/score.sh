#!/usr/bin/env bash
# Score ONE converted file already sitting at its real path, against its gold blob.
# Mechanical only — no LLM. Emits a one-line JSON object on stdout.
#
# Usage: score.sh <file_path> <gold_ref>
#   <file_path>  real repo path, e.g. src/foo/src/Shared/Foo.lua  (file already written there)
#   <gold_ref>   git ref of the maintainer-approved version, e.g. b9790d3612
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
FILE="$1"; GOLD_REF="$2"

# --- header: is it --!strict?
HEADER="$(head -1 "$FILE" | tr -d '\r')"
STRICT=false; [ "$HEADER" = "--!strict" ] && STRICT=true

# --- single-file analyze (same engine/flags as lint:luau, pinned old solver)
ANALYZE_OUT="$(luau-lsp analyze \
  --sourcemap=sourcemap.json --base-luaurc=.luaurc --defs=globalTypes.d.lua \
  --flag:LuauSolverV2=false --ignore='**/node_modules/**' \
  "$FILE" 2>&1 || true)"
# Count only canonical findings located IN THE TARGET FILE — luau-lsp prints "<path>(line,col): ...".
# Counting every "error" line over-counts pre-existing dependency noise (node_modules, nonstrict
# siblings) and stale-sourcemap "Unknown require" churn that isn't the conversion's fault; the final
# lint:luau gate catches genuine cross-file breakage separately. awk is pipefail-safe.
ERRORS="$(printf '%s\n' "$ANALYZE_OUT" | awk -v f="$FILE(" 'substr($0,1,length(f))==f{c++} END{print c+0}')"

# --- looseness: `any` casts/annotations vs the gold (lower-or-equal is good).
# `any`      = total anys.  `any_nonrx` = anys EXCLUDING sanctioned Rx-chain lines (casting Rx
# machinery is deliberate policy — see references/rx.md — so the budget gate uses the non-Rx count).
RX='Pipe|switchMap|combineLatest|Rx[.]|RxSignal|Observable|Brio|Signal[.]new'
count_any()       { awk '{n+=gsub(/:: *any|: *any/,"")} END{print n+0}'; }
count_any_nonrx() { awk -v rx="$RX" '$0 ~ rx {next} {n+=gsub(/:: *any|: *any/,"")} END{print n+0}'; }
ANY_FILE="$(count_any < "$FILE")"
ANY_FILE_NONRX="$(count_any_nonrx < "$FILE")"
GOLD_SRC="$(git show "$GOLD_REF:$FILE" 2>/dev/null || true)"
ANY_GOLD="$(printf '%s' "$GOLD_SRC" | count_any)"
ANY_GOLD_NONRX="$(printf '%s' "$GOLD_SRC" | count_any_nonrx)"

# --- selene: the SECOND gate. Dot-syntax conversion trips `unused_variable: self` (→ rename `_self`)
# and Rx `local X = X :: any` trips `shadowing` — both pass analyze but FAIL lint:selene (CI-failing).
# Count selene findings in the target file only. Best-effort: needs the roblox std (generate once).
[ -f roblox.yml ] || selene generate-roblox-std >/dev/null 2>&1 || true
SELENE_OUT="$(selene --display-style=Json --config=selene.toml "$FILE" 2>/dev/null || true)"
SELENE="$(printf '%s\n' "$SELENE_OUT" | grep -c '"severity"' || true)"

printf '{"file":"%s","strict":%s,"analyze_errors":%s,"selene":%s,"any":%s,"any_gold":%s,"any_nonrx":%s,"any_gold_nonrx":%s}\n' \
  "$FILE" "$STRICT" "$ERRORS" "$SELENE" "$ANY_FILE" "$ANY_GOLD" "$ANY_FILE_NONRX" "$ANY_GOLD_NONRX"
