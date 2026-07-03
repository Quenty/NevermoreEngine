# Strict typing — canonical examples & error table

Full, copyable shapes drawn from real strict files in this repo. The shapes match the project's
VS Code snippets (`tools/nevermore-vscode/snippets/luau.code-snippets`: `class`, `binder`,
`service`, `classtype`, `lib`, `pane`) — reproduce them verbatim for minimal diffs.

## Plain util / library module (no metatable)

```lua
--!strict
local require = require(script.Parent.loader).load(script)

local MyUtils = {}

function MyUtils.add(a: number, b: number): number
	return a + b
end

-- shared shapes get an export type; otherwise none is needed
export type Entry = { name: string, count: number }

return MyUtils
```

## BaseObject class

```lua
--!strict
local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")

local MyClass = setmetatable({}, BaseObject)
MyClass.ClassName = "MyClass"
MyClass.__index = MyClass

export type MyClass = typeof(setmetatable(
	{} :: {
		_enabled: ValueObject.ValueObject<boolean>,
	},
	{} :: typeof({ __index = MyClass })
)) & BaseObject.BaseObject

function MyClass.new(): MyClass
	local self: MyClass = setmetatable(BaseObject.new() :: any, MyClass)
	self._enabled = self._maid:Add(ValueObject.new(false))
	return self
end

function MyClass.SetEnabled(self: MyClass, enabled: boolean): ()
	self._enabled.Value = enabled
end

return MyClass
```

## Annotate no-return functions with `: ()`

Every function/method that doesn't return a value gets an explicit `: ()` return annotation
(see `Destroy`/`SetEnabled` above). This is the repo convention — it states "returns nothing"
on purpose rather than leaving it inferred, and it reads symmetrically with functions that do
declare a return type. Applies to constructors' siblings, lifecycle methods (`Init`, `Start`),
setters, and private helpers alike:

```lua
function MyClass.SetEnabled(self: MyClass, enabled: boolean): ()
	self._enabled.Value = enabled
end

function MyService.Init(self: MyService, serviceBag: ServiceBag.ServiceBag): ()
	-- ...
end
```

A function with only bare `return` statements (early-outs, no value) still returns nothing —
annotate it `: ()` too. Only omit the annotation when the function actually returns a value
(then annotate the real type instead).

## Binder-bound class

Same as a BaseObject class, but registered via a binder. The `:: any` on the class and the
`Binder.Binder<MyClass>` cast on the result are sanctioned:

```lua
return Binder.new("MyTag", MyClass :: any) :: Binder.Binder<MyClass>
```

The binder constructor receives `(instance, serviceBag)`; type the constructor accordingly:
`function MyClass.new(obj: Instance, serviceBag: ServiceBag.ServiceBag): MyClass`.

**Tightening a binder-bound constructor's param ripples to the BinderProvider that registers
it.** A `*BindersClient.lua` / `*BindersServer.lua` does `Binder.new("Tag", require("X"), bag)`;
once `X.new` takes a concrete type (e.g. `IntValue`) instead of being nonstrict, that registration
fails the `(Instance) -> any | ClassDefinition<any> | ...` union and needs the sanctioned `:: any`.
But **do NOT write `require("X") :: any`** — luau-lsp's require resolver only fires on a *bare*
`require(...)` call, so casting the call expression makes it emit a spurious
`TypeError: Unknown require: .../X.lua`. Hoist the require to a module-level local and cast the
**local** instead:

```lua
local TeamKillTracker = require("TeamKillTracker")
-- ...
self:Add(Binder.new("TeamKillTracker", TeamKillTracker :: any, serviceBag))
```

## Generic class

`T` must be load-bearing — appear in a field — or `MyClass<number>` and `MyClass<string>`
collapse. If the value is dynamic, give it a virtual field:

```lua
export type ValueObject<T> = typeof(setmetatable(
	{} :: {
		Value: T,       -- virtual: served by a function __index, but keeps T flowing
		_value: T,
	},
	{} :: typeof({ __index = ValueObject })
))

function ValueObject.Observe<T>(self: ValueObject<T>): Observable.Observable<T>
	-- ...
end
```

Dynamic / function `__index`: assign the runtime metamethods through an `any` view so they don't
fight the typed `MyClass.__index = MyClass`:

```lua
local rawMyClass = MyClass :: any
rawMyClass.__index = function(self, index) ... end
```

## ServiceBag service

A service is a plain table (no parent metatable) with a `.ServiceName`, an `Init(self, serviceBag)`
and optional `Start(self)` lifecycle, and dependencies pulled from the bag via `serviceBag:GetService`.
Model the instance with `typeof(setmetatable(...))` — same as a class, but no `& Parent` intersection.

```lua
--!strict
local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local MyService = {}
MyService.ServiceName = "MyService"

export type MyService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_otherService: OtherService.OtherService,
	},
	{} :: typeof({ __index = MyService })
))

function MyService.Init(self: MyService, serviceBag: ServiceBag.ServiceBag): ()
	-- the field isn't set yet, so the typed `self` narrows it to nil — cast for the guard:
	assert(not (self :: any)._serviceBag, "MyService is already initialized!")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._otherService = serviceBag:GetService(require("OtherService"))
end

function MyService.Start(self: MyService): ()
	-- ...
end

return MyService
```

## The `t` boundary

`t` (the runtime type-checker) isn't strict-friendly. Scope an `any` to the import:

```lua
local t: any = require("t")
```

## Typing Rx + Promises returns
Always type public return methods like `PromiseRestoreDefault<T>` for example, instead of casting the return type to `any`

```lua
function AssetServiceCache.PromiseBundleDetails(self: AssetServiceCache, bundleId: number): Promise.Promise<AssetServiceUtils.BundleDetails>
	assert(type(bundleId) == "number", "Bad bundleId")

	self:_ensureInit()

	return self._promiseBundleDetails(bundleId)
end
```

For observables, you'll want to type-cast these like this

```lua
function RxBodyColorsDataUtils.observeFromAttributes(instance: Instance): Observable.Observable<BodyColorsData>
```

## Typing `MyClass:__index()` and `MyClass:__newindex` metamethods

Type these meta-methods like this if you're getting type errors.

Before:
```lua
function AdorneeValue:__index(self, value)
	-- implementation here
end
```

After:
```lua
(AdorneeValue :: any).__index = function(self, index)
	-- implementation here
end
```

## Common strict-mode errors → mechanical fix

| Error | Fix |
|---|---|
| `Key 'self' not found` / `self` has type `unknown` in a method | Method uses colon syntax — change `function C:M(...)` to `function C.M(self: C, ...)`. |
| `Cannot add property '_x' to table` in the constructor | `_x` is missing from the `export type` field record — add it with its type. |
| `Type 'X' could not be converted into 'Y'` at `setmetatable(...)` | Add `:: any` to the parent constructor result: `setmetatable(Base.new() :: any, C)`. |
| `Unknown require` / sibling exports no type | Add `export type` upstream (preferred), or write a precise structural interface of the surface you use. |
| `Type contains a self-recursive construct` / "too complex" on one heavy generic | `any` + intended-type comment on every occurrence (fields, params, returns); sweep in one pass. |
| `Key 'k' not found` on `rawget(self, k)` / `self[dynamicKey]` | Cast the receiver: `rawget(self :: any, k)`. |
| `T` not flowing (generic collapses) | Make `T` load-bearing — add a `Value: T` (or similar) field. |
| Required arg the method ignores, or optional arg passed as required | Fix the upstream signature (make optional / remove dead param) if in scope; else flag it. Don't paper with a call-site `:: any`. |
| `Internal error: Code is too complex to typecheck!` on a class typed `typeof(setmetatable(...)) & SomeMixin.Mixin` | Old solver chokes on intersecting a record (mixin surface) onto a metatable type — worsens when the class is stored in containers. **Inline** the mixin's runtime-injected fields/methods directly into the class's field record (with a `-- <Mixin> surface (injected at runtime)` comment) instead of intersecting. Type the injected methods' receivers as `self: any`. |
| `Internal error: Code is too complex to typecheck!` that PERSISTS after the mixin fix | Two more causes, apply as needed: **(a) a heavy sibling's full type in a field** (`_svc: BigService.BigService` whose type transitively expands the world) → replace with a **minimal structural interface** of only the members used: `type BigServiceLike = { MethodIUse: (self: any, ...) -> ... }`. **(b) self-recursive method resolution** — each `self:_helper()` call re-normalizes the whole class&base intersection → type the receivers of the class's **private helper methods** `self: any` (sanctioned; keep PUBLIC method `self` precise). If the parent itself expands the world: launder the metatable `setmetatable(X :: any, Base)` and swap `& Base.Base` for a structural `BaseLike`. All recoverable once LuauSolverV2 lands. |
| A typed provider/binder no longer exposes a DYNAMIC key it exposed when untyped (`Type 'BinderProvider' does not have key 'GameConfig'`) | Cast the receiver at the access: `(self._binders :: any).GameConfig`. The dynamic tag/name accessors aren't in the static type. |
| `different number of generic type pack parameters` on a `Signal`/generic metatable field when the class is used in an invariant position (`{T}` return, `table.insert(list, x)`, etc.) | Old-solver bug comparing generic metatable types invariantly across modules. Cast the element to `any` at the invariant site only (`table.insert(list, x :: any)`); keep the public/field type precise. |

## selene — the second gate (a strict conversion must pass `lint:selene` too, and it exits non-zero on these)

- **`unused_variable: self`** — converting `function C:M()` → `function C.M(self: C)` on a body that never uses `self` makes the now-explicit param unused. Rename it **`_self`** (repo idiom, 70+ uses; the leading `_` is selene's unused-allow). Callers still write `obj:M()`.
- **`shadowing`** — an Rx escape written as `local RxX = RxX :: any` *inside a function* shadows the module require. Don't. Cast at the source: `local RxX: any = require("RxX")` at the top (the sanctioned nonstrict-module boundary) and drop the per-function casts.

**moonwave (`lint:moonwave`) is a THIRD gate the conversion can break** (docstrings, not types — run `moonwave-extractor extract src` in the package):
- `@type Name` with **no type value** → "Property type is required". Give it the value: `@type ModifierInputChord { type: "ModifierInputChord", ... }`.
- Converting a metamethod `function C:__index(i)` → `(C :: any).__index = function(self, i)` **loses moonwave's class association**, so its docstring now needs an explicit `@within C` tag ("Function requires @within tag").

**A cross-package `Expected 'X' but got 'X'` (same name) may be un-reproducible locally and unfixable by casting** — it's a luau-lsp V1-solver symlink-nominal cache flake whose appearance depends on CI's file-resolution order. If casting every value on the line doesn't clear it and you can't reproduce it, the honest escape is to drop *that one file* to `--!nonstrict` and flag it.
| A direct cast `v :: T` rejected as **"types are unrelated"** (e.g. a metatable'd `setmetatable({number}, mt)` alias vs a plain `{number}`) | Old solver won't cast between unrelated types in one step — launder through `any`: `(v :: any) :: T`. Same trick to reach a metatable method the alias type doesn't surface: `(v :: any):method()`. Sound when `v` genuinely is a `T` at runtime; keep the public signature precise. |

## Common type imports

`ServiceBag.ServiceBag`, `Maid.Maid`, `Observable.Observable<T>`, `Brio.Brio<T>`,
`ValueObject.ValueObject<T>`, `Signal.Signal<T>`, `BaseObject.BaseObject`, `Binder.Binder<T>`.
