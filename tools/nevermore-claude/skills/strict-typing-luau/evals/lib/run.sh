#!/usr/bin/env bash
# Mechanical eval harness for the strict-typing-luau skill. No LLM in --gold mode.
#
#   run.sh gold      Smoke test: lay down the maintainer's GOLD for each case and score it.
#                    Every positive case MUST come back strict + 0 analyze errors. Proves the
#                    pairs, the scorer, and the plumbing are all sound. ~minutes, no tokens.
#
#   run.sh place <id>     Worker loop primitive: put the pre-conversion (nonstrict) INPUT at
#                         the file's real path so an agent can convert it in place.
#   run.sh score <id>     Score whatever is at the file's path now, vs gold.
#   run.sh restore <id>   Restore the file's package back to its committed state (HEAD, undo place/convert).
#   run.sh plan <pkg>     Print the INTRA-PACKAGE conversion order (dependency-first, cyclic
#                         clusters collapsed). The orchestration artifact a driver walks. Add
#                         `json` for machine-readable output. Intra-package only — see plan.js.
#   run.sh convert <pkg> <input_ref> [--run]
#                         Whole-package conversion driver: walk the plan, fresh model-routed worker
#                         per node, any-budget gate, final lint:luau. DRY-RUN unless --run (which
#                         spawns claude -p workers and spends tokens). See convert.sh.
#   run.sh sync           Rebuild sourcemap.json to match the current tree. Call it AFTER a
#                         whole-package conversion in which the agent ADDED files (e.g. a new
#                         shared Types.lua) — otherwise single-file analyze can't resolve them
#                         (the stale-sourcemap trap). After restoring such a run, `sync` once
#                         more to return the sourcemap to main. Single-file runs don't need it.
#   run.sh triggers       Judge whether the skill's DESCRIPTION fires correctly (one claude -p call).
#   run.sh tooling        Judge whether the skill scopes the right ACTION — planner for a whole
#                         package, direct conversion for a single file/scoped node (guards against
#                         single-file workers over-orchestrating). One claude -p call.
#   run.sh parallelism    Judge the execution STRATEGY — fan out parallel sub-agents for a package
#                         (> ~3 files) vs sequential for a single file/handful. One claude -p call.
#   run.sh routing        Mechanical (no-LLM, ~instant): assert plan.js's model heuristic routes a
#                         ServiceBag service (.ServiceName, no setmetatable) to opus, a plain util to
#                         sonnet. Reads plan.js's real predicate so it can't drift. See routing.js.
#
# Files are laid down at PACKAGE granularity (src/<pkg>) because a package is the unit of
# type-consistency: a cyclic file scored against nonstrict siblings would error falsely.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/../manifest.json"

field() { node -e "const manifest=require('$MANIFEST');const found=manifest.cases.find(c=>c.id==='$1');if(!found){process.exit(3)}process.stdout.write(found['$2']||'')"; }
ids()   { node -e "const manifest=require('$MANIFEST');console.log(manifest.cases.map(caseItem=>caseItem.id).join(' '))"; }
pkg_of(){ echo "$1" | sed -E 's#(src/[^/]+)/.*#\1#'; }

place_gold(){ local filePath; filePath="$(field "$1" path)"; git checkout "$(field "$1" gold)"  -- "$(pkg_of "$filePath")"; }
place_in()  { local filePath; filePath="$(field "$1" path)"; git checkout "$(field "$1" input)" -- "$(pkg_of "$filePath")"; }
restore()   { local filePath pkgDir; filePath="$(field "$1" path)"; pkgDir="$(pkg_of "$filePath")";
              # back to the current branch's committed state (HEAD), unstage, and remove gold-only
              # NEW files (e.g. a new *Types.lua). HEAD not main: on main they're identical, but on a
              # feature branch `git checkout main` would revert the branch's own work in this package.
              git checkout HEAD -- "$pkgDir" 2>/dev/null || true
              git reset -q HEAD -- "$pkgDir"; git clean -fdq -- "$pkgDir"; }
score()     { bash "$HERE/score.sh" "$(field "$1" path)" "$(field "$1" gold)"; }

case "${1:-}" in
  place)   place_in "$2" ;;
  score)   score "$2" ;;
  restore) restore "$2" ;;
  sync)    npm run build:sourcemap >/dev/null 2>&1 && echo "sourcemap rebuilt to current tree" ;;
  plan)    shift; node "$HERE/plan.js" "$@" ;;
  convert) shift; bash "$HERE/convert.sh" "$@" ;;
  triggers)    bash "$HERE/judge.sh" triggers prompts ;;
  tooling)     bash "$HERE/judge.sh" tooling tasks ;;
  parallelism) bash "$HERE/judge.sh" parallelism tasks ;;
  routing)  node "$HERE/routing.js" ;;
  gold)
    printf '%-22s %-8s %-6s %-8s %-7s %-5s %-7s %s\n' CASE POLARITY STRICT ANALYZE SELENE ANY RAW VERDICT
    fails=0
    get() { node -e "process.stdout.write(String(JSON.parse(process.argv[1]).$1))" "$row"; }  # one field of the score row
    for id in $(ids); do
      pol="$(field "$id" polarity)"
      place_gold "$id"
      row="$(score "$id")"
      restore "$id"
      strict="$(get strict)"; errs="$(get analyze_errors)"; selene="$(get selene)"
      any="$(get any)"; raw="$(get raw)"; raw_gold="$(get raw_gold)"
      # gold expectation: positive => strict & 0 analyze errors & 0 selene findings & no raw-access
      # regression (raw >= raw_gold, tautological on gold — proves the check doesn't false-positive);
      # negative => nonstrict (reverted)
      verdict=PASS
      if [ "$pol" = positive ]; then
        { [ "$strict" = true ] && [ "$errs" -eq 0 ] && [ "$selene" -eq 0 ] && [ "$raw" -ge "$raw_gold" ]; } || { verdict=FAIL; fails=$((fails+1)); }
      else
        [ "$strict" = false ] || { verdict=FAIL; fails=$((fails+1)); }
      fi
      printf '%-22s %-8s %-6s %-8s %-7s %-5s %-7s %s\n' "$id" "$pol" "$strict" "$errs" "$selene" "$any" "$raw/$raw_gold" "$verdict"
    done
    echo
    [ "$fails" -eq 0 ] && echo "GOLD SMOKE TEST: all cases passed" || { echo "GOLD SMOKE TEST: $fails FAILED"; exit 1; }
    ;;
  *) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
