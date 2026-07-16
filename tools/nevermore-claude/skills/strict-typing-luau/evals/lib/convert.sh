#!/usr/bin/env bash
# Whole-package conversion driver — the orchestration capstone. Walks the `plan` order, spawns a
# fresh model-routed worker per node (claude -p), scores each, applies the any-budget gate
# (escalate a loose Sonnet node to Opus), then one sourcemap sync + lint:luau at the end.
#
#   convert.sh <pkg> <input_ref> [--run] [--limit N]
#     <pkg>        package dir, e.g. src/settings
#     <input_ref>  git ref holding the pre-conversion (untyped) package, e.g. b1bc1512aa
#     --run        ACTUALLY spawn workers (spends tokens/time). Omitted = DRY RUN.
#     --limit N    only the first N convertible units (for a bounded slice)
#
# Converts ONLY files that are --!strict on main (real strict gold to score against); files left
# nonstrict on main stay at main, so each target converts against the same conditions the gold did.
# Fresh worker per node = fresh context, so each node imports its already-converted deps' real types.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/../../SKILL.md"
PKG="${1:?usage: convert.sh <pkg> <input_ref> [--run] [--limit N]}"
INPUT="${2:?need input ref}"
RUN=0; LIMIT=0
args=("$@")
for ((i = 2; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = "--run" ] && RUN=1
  [ "${args[$i]}" = "--limit" ] && LIMIT="${args[$((i + 1))]:-0}"
done
SLACK=2   # any_nonrx may exceed gold_nonrx by this much before the gate escalates to Opus

# convertible units (>=1 target), honoring --limit: step \t model \t kind \t comma-joined TARGET rels
units_tsv() {
  node -e '
    const {execSync}=require("child_process");
    const p=JSON.parse(execSync(`node '"$HERE"'/plan.js '"$PKG"' json --eval-gold`).toString());
    let u=p.units.filter(x=>x.targets.length);
    const lim='"$LIMIT"'; if(lim>0) u=u.slice(0,lim);
    for(const x of u) console.log([x.step,x.model,x.kind,x.targets.join(",")].join("\t"));
  '
}
all_targets() { units_tsv | cut -f4 | tr ',' '\n' | sed '/^$/d'; }

worker_prompt() { # model "rel1,rel2"
  local files; files="$(echo "$1" | tr ',' '\n' | sed "s#^#$PKG/src/#")"
  cat <<EOF
Convert the following file(s) to --!strict following the project's strict-typing-luau skill: read
$SKILL first (and references/conventions.md, references/rx.md as needed).

Files to convert (edit ONLY these):
$files

Constraints (scoped node in a package-wide conversion):
- Edit only the file(s) listed. Their dependencies are already at their final state — import real
  types where a dep is strict; use the skill's structural/any escape where a dep is still nonstrict.
- Verify with the single-file luau-lsp analyze loop from the skill, NOT repo-wide lint:luau.
- If multiple files are listed they are a cyclic cluster — convert them together (cyclic-types playbook).
- Rx chains: cast on the first analyze error per references/rx.md; keep public return types precise.
- Stop the moment single-file analyze is clean. Hard cap ~6 analyze runs per file.
EOF
}
run_worker() { claude -p --model "$1" --permission-mode acceptEdits "$(worker_prompt "$2")" >/dev/null 2>&1 || true; }

# ---- DRY RUN (default) ----
if [ "$RUN" -ne 1 ]; then
  echo "DRY RUN — convert $PKG from $INPUT${LIMIT:+ (limit ${LIMIT})} (no workers; pass --run to execute)"
  echo "Would: place each target's untyped $INPUT version (non-targets stay at main), then per node:"
  echo
  printf '%-4s %-7s %-8s %s\n' STEP MODEL KIND TARGETS
  while IFS=$'\t' read -r step model kind targets; do
    printf '%-4s %-7s %-8s %s\n' "$step" "$model" "$kind" "$targets"
  done < <(units_tsv)
  echo
  echo "Per node: fresh \`claude -p --model <model>\` -> score.sh -> if sonnet & any_nonrx >"
  echo "any_gold_nonrx+$SLACK (or not clean), re-run node on opus. Then sync + npm run lint:luau."
  exit 0
fi

# ---- REAL RUN ----
echo ">> placing $(all_targets | wc -l | tr -d ' ') target file(s) at $INPUT (non-targets stay at main)"
git checkout main -- "$PKG"; git reset -q HEAD -- "$PKG"; git clean -fdq -- "$PKG"
while read -r t; do
  full="$PKG/src/$t"
  git show "$INPUT:$full" > "$full" 2>/dev/null || { echo "  !! $t missing at $INPUT — aborting"; git checkout main -- "$PKG"; exit 1; }
done < <(all_targets)
npm run build:sourcemap >/dev/null 2>&1

printf '%-4s %-7s %-7s %-7s %-11s %s\n' STEP MODEL STRICT ERRORS ANYnonrx FILE
while IFS=$'\t' read -r step model kind targets; do
  run_worker "$model" "$targets"
  npm run build:sourcemap >/dev/null 2>&1   # sync before scoring — a worker may have shifted the
                                            # tree; a stale sourcemap yields phantom analyze errors
  for rel in ${targets//,/ }; do
    f="$PKG/src/$rel"
    row="$(bash "$HERE/score.sh" "$f" main)"
    get() { node -e "process.stdout.write(String(JSON.parse(process.argv[1]).$1))" "$row"; }
    strict="$(get strict)"; errs="$(get analyze_errors)"; anr="$(get any_nonrx)"; gnr="$(get any_gold_nonrx)"
    gate=""
    if [ "$model" = sonnet ] && { [ "$strict" != true ] || [ "$errs" -ne 0 ] || [ "$anr" -gt $((gnr + SLACK)) ]; }; then
      gate="-> escalated opus"
      run_worker opus "$targets"
      row="$(bash "$HERE/score.sh" "$f" main)"; strict="$(get strict)"; errs="$(get analyze_errors)"; anr="$(get any_nonrx)"
    fi
    printf '%-4s %-7s %-7s %-7s %-11s %s %s\n' "$step" "$model" "$strict" "$errs" "$anr/$gnr" "$rel" "$gate"
  done
done < <(units_tsv)

echo; echo ">> final gate: npm run lint:luau (new errors in $PKG only)"
npm run build:sourcemap >/dev/null 2>&1
npm run lint:luau 2>&1 | grep -E "$PKG" | grep -iE 'error' | head -20 || echo "  none"
echo ">> conversion left in tree. Restore: git checkout main -- $PKG && git reset -q HEAD -- $PKG && git clean -fdq -- $PKG && npm run build:sourcemap"
