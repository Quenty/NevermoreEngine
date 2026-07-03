# strict-typing-luau — mechanical eval harness

A fast, deterministic, **no-LLM** way to validate the skill. Cases are mined from **main
history**: real nonstrict→strict conversions the maintainers shipped. Each case stores the
pre-conversion blob (`input`) and anchors `gold` to **main HEAD**, so single-file analyze always
matches the main-built sourcemap (no staleness). See `manifest.json`.

## The checks

### 1. Gold smoke test (~20s, no tokens) — validates the harness itself

```bas
bash evals/lib/run.sh gold
```

Scores the maintainer's gold (main) for every case. Every positive must come back
`strict=true, analyze=0`; negatives must be `strict=false`. If this is green, the pairs, the
scorer, and the plumbing are sound. Run it after editing the manifest or scorer.

### 2. Worker eval — measures an actual skill run

Per case, drive the worker (an agent running the skill) with these primitives:

```bash
bash evals/lib/run.sh place   <case_id>   # lay the nonstrict INPUT at the file's real path
#   ... run the skill on that path to convert it in place ...
bash evals/lib/run.sh score   <case_id>   # -> {strict, analyze_errors, selene, any, any_gold}
bash evals/lib/run.sh restore <case_id>   # undo: restore the package to main
```

A conversion **passes** when `strict=true`, `analyze_errors=0`, `selene=0`, and `any_nonrx <= any_gold_nonrx`
(no looser than the maintainer's output, *excluding* Rx-chain casts — those are deliberate policy,
see `references/rx.md`). `selene` is the SECOND gate (CI-failing): dot-syntax conversion trips
`unused_variable: self` (→ rename `_self`) and an Rx `local X = X :: any` trips `shadowing` (→
`local X: any = require`), both of which pass analyze but fail selene — so the scorer counts selene
findings in the target file. `score.sh` reports both the total `any` and the budgeted `any_nonrx`. Run
`npm run lint:luau` once at the end as the downstream gate.

**Whole-package runs.** Cases sharing an `input` commit belong to one package conversion — e.g.
the six `settings-*` cases (all `input: b1bc1512aa`, `src/settings`, the `PlayerSettings` package
the maintainers strict-typed in PR #550). `place` any one of them and the whole package drops to
its untyped state; the agent then converts every file (leaves first — see their manifest order),
and you `score` each case. If the agent **added** a file during conversion (a shared `Types.lua`),
`run.sh sync` before scoring so single-file analyze can resolve it, then `restore` + `sync` again
to return the sourcemap to main. (Single-file conversions that add nothing don't need `sync`.)

### 3. Triggering test (~5s, one judge call) — validates the `description`

```bash
bash evals/lib/triggers.sh
```

Does the skill's frontmatter `description` fire on the right prompts and stay quiet on near-misses?
Cases live in `triggers.json` (positives + hard negatives like TypeScript-strict, tsconfig-strict,
formatting). A judge model (`claude -p`) sees only the *live* description from SKILL.md and each
prompt, returns fire/skip per prompt, and we score against `expect`. The judge reads the current
description, so this catches a description edit that quietly breaks (or over-broadens) triggering.
Add a case = one line in `triggers.json`.

### 4. Tooling-scope test (~6s, one judge call) — guards against over-orchestration

```bash
bash evals/lib/run.sh tooling
```

Now that SKILL.md surfaces the planner and harness, a single-file worker could wrongly run `plan`
or the eval harness instead of just converting its file. A judge reads the *live* SKILL.md and
classifies each task in `tooling.json` as `planner` (whole-package only) or `direct` (single file /
scoped node / error-fix), scored against `expect`. Catches a SKILL.md edit that over-broadens the
planner's apparent scope. Add a case = one line in `tooling.json`.

### 5. Parallelism test (~9s, one judge call) — execution strategy at scale

```bash
bash evals/lib/run.sh parallelism
```

A judge reads the live SKILL.md and classifies each `parallelism.json` task as `parallel` (fan out
one sub-agent per file within a dependency layer, for a package > ~3 files) or `sequential` (single
file / handful / error-fix). Guards the real-use regression where the agent converted a whole package
serially because the skill never told it to parallelize.

### 6. Routing test (~instant, no LLM) — model routing heuristic

```bash
bash evals/lib/run.sh routing
```

Mechanical assert on `plan.js`'s model routing: a **ServiceBag service** (`.ServiceName`, a plain
table with no `setmetatable`) must route to **opus**, a plain util to **sonnet**. It reads `plan.js`'s
real `isClass` predicate (single source of truth, so it can't drift) and applies the same model rule
to inline samples — no fixtures, no git, no judge call. Guards the real-use regression where a service
mis-routed to sonnet got a shallow conversion (colon syntax, no `export type`) that broke a consumer.
Add a case = one entry in `routing.js`'s `cases`.

## Design notes

- **Files are placed at package granularity** (`src/<pkg>`): a package is the unit of
  type-consistency, so a cyclic file scored against nonstrict siblings won't error falsely.
- **`restore` unstages and cleans** gold-only new files (e.g. a new `*Types.lua`) so cases can't
  leak into each other.
- **Budget enforcement belongs here, not in the skill prose.** Cap the worker's tokens/iterations
  in the runner; if it can't finish a case in budget, that's a recorded failure, not a reason to
  add more instructions to SKILL.md.
- **Negatives** come from the revert commit `9027756cd7` (a naive flip that broke downstream and
  was reverted). They exist to prove the downstream `lint:luau` gate fires.
- **Model routing (per node, not per file).** `plan` tags each unit with a suggested worker model:
  **opus** for class / cyclic-cluster / Rx-importing nodes (precision + comprehension matter),
  **sonnet** for mechanical leaf/util nodes (speed is free, little to cast loosely). Backed by
  probes on a hard Rx class: Sonnet is fastest (3.1 min vs Opus 5.5) but casts ~3× more `any`
  (34 vs 12) — fine where looseness is cheap, not where it isn't. **Do not** split one hard file
  across models as a Sonnet-draft→Opus-polish pipeline: measured 2× the cost of Opus-alone with no
  precision gain (the polish pass re-comprehends from scratch; post-hoc `any`-tightening is harder
  than typing precisely up front). Route whole *nodes*, never halves of a file.
- **`any`-budget gate** (for a Sonnet-first driver): after scoring a node, if `any_nonrx >
  any_gold_nonrx + slack`, re-run that node on Opus. Uses the budgeted count, so heavy Rx casting
  (sanctioned) never trips the gate — only genuine non-Rx looseness does.

## Adding a case

Pick a file currently `--!strict` on main, find the commit that introduced it, and use its parent
as `input` (both must be reachable from main):

```bash
f=src/<pkg>/src/<Realm>/<File>.lua
c=$(git log -S'--!strict' --reverse --format='%H' -- "$f" | head -1)
git merge-base --is-ancestor "$c" main && echo "on main: input=$(git rev-parse --short "$c^")"
```

Add `{ id, archetype, path, input: "<C^ sha>", gold: "main", polarity: "positive" }` to
`manifest.json`, then re-run the gold smoke test.
