---
name: strict-typing-luau
description: Convert a Nevermore Luau file from --!nonstrict (or untyped/--!nocheck) to --!strict, adding the project's explicit type annotations and fixing every type error the checker reports. Use this whenever the user asks to "strictly type", "add types to", "make strict", "type-annotate", "convert to --!strict", or clean up the typing on a .lua/.luau file in this repo — including when they just select a file with a `--!nonstrict` header and say "type this" or point you at a legacy module. Also use it when a strict file is throwing luau-lsp type errors and the user wants them resolved following Nevermore conventions.
---

# Strictly typing Luau files

Convert a file to `--!strict` and make it pass the type checker cleanly. This is mostly
**mechanical pattern application** — move fast and correctly. The checker is your fast
feedback loop; lean on it instead of guessing.

## Triage first — match effort to the file

- **Plain util / data module** (`local X = {}` of functions, or a `return {...}` table; no
  `setmetatable`): flip the header, give every function typed params/returns, run single-file
  analyze. Usually no `export type` block needed.
- **Class** (`setmetatable({}, ...)` + constructor + methods): the real work — needs the
  `export type` block. Follow the patterns below and `references/conventions.md`.
- **Already `--!strict` but erroring**: skip conversion; just resolve the reported errors.

## Why it's not find-and-replace

Luau can't infer fields through `setmetatable`, so strict mode turns that blind spot into
errors. The fix is an explicit `export type` block enumerating every `self` field, plus
dot-syntax methods that name `self`. Flipping the header without these just produces a wall
of errors — supplying the types the checker can't infer *is* the job.

## The verification loop (fast inner loop)

`luau-lsp analyze` is the same engine as `lint:luau`, pointed at one file (~2.5s). One-time
setup if `sourcemap.json` / `globalTypes.d.lua` are missing at repo root: `npm run prelint:luau`.

```bash
luau-lsp analyze --sourcemap=sourcemap.json --base-luaurc=.luaurc \
  --defs=globalTypes.d.lua --flag:LuauSolverV2=false --ignore='**/node_modules/**' \
  src/<package>/src/<Realm>/<File>.lua
```

Clean = only the `[INFO] Loading...` line. `LuauSolverV2=false` is required (repo pins the old
solver). **Never drop `--defs=globalTypes.d.lua` or `--base-luaurc=.luaurc`** — without `--defs`
the analyzer loses the Roblox global declarations and reports *false* `Unknown global 'tick'/'time'`
(and similar) errors while still resolving `game`/`Enum`, which looks like a real conversion bug but
isn't. If you see unknown-global errors only on deprecated globals, you forgot `--defs`; confirm with
`npm run lint:luau` (which always passes the flag) before "fixing" anything. Iterate until clean,
then run `npm run lint:luau` **once** as the final gate — single-file
analyze can't see files that depend on *yours*, and tightening a type ripples to subclasses and
callers. Triage new downstream errors: pre-existing → leave & flag; your type is genuinely too
tight for the real contract → loosen *your* type (often `T?` not `T`); a small obvious follow-on
→ fix it.

## Core patterns

**Class with a parent (the common case):**

```lua
--!strict
local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local MyClass = setmetatable({}, BaseObject)
MyClass.ClassName = "MyClass"
MyClass.__index = MyClass

export type MyClass = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,   -- EVERY self field, with its type
		_enabled: ValueObject.ValueObject<boolean>,
	},
	{} :: typeof({ __index = MyClass })
)) & BaseObject.BaseObject   -- intersection pulls in inherited _maid, _obj, etc.

function MyClass.new(serviceBag: ServiceBag.ServiceBag): MyClass
	local self: MyClass = setmetatable(BaseObject.new() :: any, MyClass)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	return self
end
```

**Methods use dot syntax with explicit `self`** (colon syntax loses the `self` type in strict
mode). Callers still write `obj:Method()`; only the definition changes:

```lua
function MyClass.GetEnabled(self: MyClass): boolean
	return self._enabled.Value
end
```

## The export type rule — always `typeof(setmetatable(...))`, never hand-list methods

There is **one** way to write a class's export type, and it holds for generic, inherited, and
dynamic-`__index` classes alike:

```lua
export type MyClass = typeof(setmetatable(
	{} :: { ...only the instance FIELDS... },
	{} :: typeof({ __index = MyClass })
)) [& Parent.Parent]
```

Methods come from `typeof({ __index = MyClass })` — never hand-write `Method: (self, ...) -> ...`
records (they drift and cost enormous churn on big classes). Inheritance: list only the child's
*own new* fields; inherited ones arrive via `& Parent.Parent`. Generics: keep `<T>` load-bearing
by putting it in a field (e.g. a virtual `Value: T`); never collapse `<T>` to `any`. The one tax:
a metatable'd type needs `self :: any` for dynamic self-access (`rawget(self :: any, k)`).

## When `:: any` is acceptable

Confined to boundaries the checker genuinely can't model:

- `setmetatable(ParentClass.new(...) :: any, MyClass)` — the metatable transform
- `Binder.new("Tag", MyClass :: any) :: Binder.Binder<MyClass>` — binder registration
- `local t: any = require("t")` — `t` (and the rare library like it) isn't strict-friendly
- **Rx / reactive chains** (`:Pipe({...})`, `switchMap`/`map` closures, `RxSignal`, `Signal.new()`)
  — the #1 time-sink. Don't try to thread types through them; cast to `any` on the *first* analyze
  error and move on, keeping the public return type precise. See `references/rx.md`.

**Cast the chain body, never the public return type.** Type every public method's return precisely
(`Promise.Promise<T>`, `Observable.Observable<T>`); only the internal *expression* producing it may
be `any`. Casting the return type itself is the single biggest source of avoidable looseness — a
`GetX(self): any` leaks `any` to every caller. See the Rx/Promise examples in `references/conventions.md`.

Reaching for `:: any` inside a method body means the `export type` block is wrong — fix it there.
A call-site `(x :: any):Method()` to dodge a *signature mismatch* is a smell: usually the upstream
signature is too strict (a param that should be optional) — fix it upstream if in scope, else flag
it. Don't bury a real type bug under a cast.

## Hard cases — try the precise type first, loosen the narrowest spot only

Concrete metatable types (`Signal.Signal<T>`, `ValueObject.ValueObject<T>`, `Maid.Maid`) import
and check cleanly almost always — write them out. Only these justify deviating:

1. **A type you cannot import** (sibling is still nonstrict, exports no type) → write a **precise
   structural interface** of the exact surface you use (real signatures, real field types) — this
   is typing by another means, not a loosening. Better, if cheap: add the `export type` upstream.
2. **A heavy cyclic generic** the old solver can't hold (a deep class wrapped across many
   members) → type each occurrence as `any` with JUST the intended type in a trailing comment:
   `_indexObservers: any, -- ObservableSubscriptionTable<T?>`. Find the one culprit type and sweep
   **all** its occurrences in one pass (fields, params, **returns**), don't bisect.
3. **Require cycle** between a class and its definition/factory → hoist shared shapes into a
   types-only `<Package>Types.lua` (requires nothing at runtime, so importing it can't recreate the
   cycle). Keep the public API precise; only the internal back-reference may give.

Time-box it: if a file won't go clean within ~2 iterations on the *same* cyclic/"too complex"
error, take the escape for that member and move on. The public API must stay precise; internal
plumbing can absorb imprecision.

## Comment discipline

**Default: write loose `any`s BARE — no explanatory comment.** Write `_cmdrService: any,` — NOT
`_cmdrService: any, -- CmdrServiceClient (nonstrict, no exported type)`. This holds for *every* `any`
whose source module simply exports no type yet (the common case). The comment reads as "blessed,
intentional" and discourages the next person from tightening it — and we *want* these `any`s gone. A
bare `any` is honest debt; a commented one looks finished. Don't explain yourself.

Only two exceptions earn a comment:
- **A forced cyclic-complexity `any`** (Hard case #2) records its intended type so it's recoverable:
  `_indexObservers: any, -- ObservableSubscriptionTable<T?>`. The comment is *information*, not an apology.
- **A non-obvious deliberate structure** (e.g. a structural type dodging a require cycle) gets a line
  so no one "fixes" it back into the cycle.

If you're tempted to comment an `any` for any other reason — don't.

## Report your hand-offs

End with a short **"Hand-offs"** list: every spot where you took an escape instead of a precise
type — file, member, the `any`/structural fallback, and the intended type. Skip routine sanctioned
boundaries (metatable casts, `t: any`, binder registration). This is the deliverable that lets the
user tighten later; a run that loosened things silently is not done.

## Pitfalls

- **`--!strict` must be the file's FIRST line** — before the `--[=[ ]=]` docstring. Luau only honors
  a mode directive at the very top; placed after the docstring it's silently ignored and the file is
  never strict-checked (analyze looks "clean" but isn't).
- Don't leave `--!nonstrict`/`--!nocheck` "for safety" — the point is `--!strict`.
- Don't run repo-wide `lint:luau` on every edit — single-file analyze is the inner loop, `lint:luau`
  is the final gate.
- Don't invent fields — the `export type` block must list exactly what `self` gets.
- Keep legacy/deprecation docstrings; typing doesn't change deprecation status.

## Tooling

- `references/conventions.md` — full canonical examples + a common-error → fix table.
  `references/rx.md` — the Rx/reactive escape in detail.
- **Converting a whole package?** Don't eyeball the order. Run the planner for a
  dependency-ordered, model-routed conversion plan — which files, in what order, and which form
  cyclic clusters to convert together:

  ```bash
  # from the repo root (the script cd's to the repo top itself, so CWD doesn't matter):
  .claude/skills/strict-typing-luau/evals/lib/run.sh plan src/<package>     # e.g. src/settings
  ```

  It defaults to **real mode** (targets the files that aren't `--!strict` yet); convert leaves-first
  in the order it prints. (`--eval-gold` switches it to the harness's gold-bearing view.)
- **Parallelize at scale.** Files in the same dependency layer of the plan are independent — they
  don't require each other, so they can convert concurrently. When a package has **more than ~3
  files to convert**, fan out **one sub-agent per file within a layer** (launch them in a single
  message so they run in parallel), wait for the layer, then move to the next. Each sub-agent
  converts ONE file against its already-converted deps. This makes wall-clock ≈ the slowest file per
  layer instead of the sum, and keeps each context small. At ≤3 files, just convert sequentially —
  the fan-out overhead isn't worth it.
- That same **`run.sh`** with no arguments lists every command. `plan` is the one generally useful
  for real conversions; the rest (`gold`, `convert`, `place`/`score`/`restore`, `triggers`) *evaluate*
  the skill — see `evals/README.md` for those workflows.
