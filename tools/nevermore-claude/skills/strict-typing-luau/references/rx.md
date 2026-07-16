# Rx / reactive chains — cast first, don't fight

Reactive machinery (`Rx.*` pipe chains, `RxSignal`, `Observable`/`Brio` used across many members)
is the **single biggest time-sink** in a strict conversion. The old solver can't thread types
through `:Pipe({...})`, `switchMap`, or a heavy reactive field, and every attempt spawns a fresh
"too complex" / duplicate-`Observable`-module error. Do **not** iterate on these. The instant an
analyze error mentions a Pipe chain, an Rx operator, `RxSignal`, or an `Observable` unification,
**cast to `any` and move on** — that's the established answer, not a failure.

The discipline that keeps this honest: **type the public surface precisely, cast only the internal
chain.** A method's *declared* return type imports fine — it's the *expression* producing it that
won't check.

## Patterns — what to cast, what to keep precise

**Pipe chains** — keep the declared return; cast the chain body:
```lua
function MyClass.Observe(self: MyClass): Observable.Observable<T>   -- precise public return
	return (self._value :: any):Pipe({                              -- cast the receiver/chain
		Rx.distinct(),
		Rx.map(function(v): any                                      -- operator closures: -> any
			return transform(v)
		end),
	})
end
```

**Operator closures** (`Rx.map`, `Rx.switchMap`, `Rx.combineLatest`, …) — annotate the closure
return as `any`; don't try to type the intermediate stream value:
```lua
Rx.switchMap(function(playerSettings): any
	return playerSettings:Observe()
end)
```

**Heavy reactive FIELDS that trip "too complex"** (`RxSignal.RxSignal<T>`, or `Observable`/`Brio`
used in lots of fields/returns) — `any` with the intended type in a trailing comment, immediately:
```lua
Changed: any, -- RxSignal.RxSignal<T> (heavy metatable; old solver can't hold it)
```

**Constructors of reactive primitives** — cast at the boundary:
```lua
local signal = Signal.new() :: any
local rxSignal = RxSignal.new((self:Observe() :: any):Pipe({ ... }))
```

## What you STILL type precisely (don't over-cast)

- **Declared method return types**: `Observable.Observable<T>`, `Brio.Brio<T>`, `Promise.Promise<()>`
  as the *signature* — these import cleanly. Only the producing expression gets the cast.
- **Plain `ValueObject`/`Signal` FIELDS** that aren't in a chain and don't trip "too complex" —
  write the real type (`_enabled: ValueObject.ValueObject<boolean>`). Cast is for the chain and the
  fields that actually overflow the solver, not every reactive-looking thing.

## The rule

Rx is the canonical case of the skill's time-box: **first analyze error mentioning a Pipe /
operator / `RxSignal` / `Observable`-unification → cast that spot to `any` and continue.** Do not
re-run hoping to thread it precisely; you'll spend dozens of analyze loops to land on the same
`any`. Keep the public return types precise; let the internal chain be `any`.
