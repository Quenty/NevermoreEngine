---
title: Core Patterns
sidebar_position: 3
---

# Core Patterns

Beyond [ServiceBag](servicebag.md), Nevermore uses several patterns that appear throughout the codebase. Understanding these makes it much easier to read and write Nevermore code.

## Maid

A resource cleanup manager that tracks tasks — functions, connections, Instances, threads — and cleans them all up at once. Central to Nevermore's lifecycle model.

```lua
local maid = Maid.new()

-- Track a connection
maid:GiveTask(workspace.ChildAdded:Connect(function(child)
	print("Child:", child.Name)
end))

-- Track a cleanup function
maid:GiveTask(function()
	print("Cleaning up!")
end)

-- Named tasks auto-replace: assigning a new value cleans the old one
maid._character = workspace:FindFirstChild("OldCharacter")
maid._character = workspace:FindFirstChild("NewCharacter") -- OldCharacter destroyed

maid:DoCleaning() -- Disconnects, destroys, and runs everything
```

**Key API:** `Maid.new()`, `:GiveTask(task)`, `:Add(task)`, `maid[key] = task` (named), `:DoCleaning()` / `:Destroy()`

The three adders return different things, which matters when you want to keep using the value: `:GiveTask(task)` returns a numeric task id, `:Add(task)` returns the task itself, and `:GivePromise(promise)` returns a *wrapper* promise — cleaning the maid settles the wrapper, not the promise you passed in. To hold a reference and have cleanup cancel the original, use `:Add`.

**When to use:** Any time you create connections, spawn threads, or instantiate objects that need cleanup. Almost every class uses one.

### Register with the parent maid before attaching `Finally`

A common shape is a short-lived maid, scoped to one async operation, parked on a long-lived one:

```lua
self._maid[opMaid] = opMaid
opMaid:GiveTask(function()
	self._maid[opMaid] = nil
end)

promise:Finally(function()
	self._maid[opMaid] = nil   -- must come after the registration above
end)
```

Written the other way round it leaks, silently and only sometimes. Our promises settle *synchronously* when the work is already done — an `:Then` on a resolved promise runs inline — so a `Finally` attached first fires immediately, removes an entry that isn't there yet, and then the registration lands with nothing left to clear it. The entry survives for the lifetime of the owner. It looks correct in review and behaves correctly whenever the operation happens to be genuinely async, which is what makes it easy to miss.

`Maid:GivePromise` already does this correctly and is worth reading as the reference — it registers before attaching `Finally`, and early-outs entirely when the promise is already settled. Reach for it when the thing you're tracking *is* the promise. Hand-roll only when it isn't (tracking a sub-maid that owns the intermediate work, say), and then copy the ordering exactly.

The invariant is worth asserting directly: bind, release, and check the owner's task count is back where it started. Repeating the cycle ten times turns a slow leak into an obvious one.

## BaseObject

A lightweight base class that gives you a `_maid` and optional `_obj` reference for free. Nearly all Nevermore classes inherit from it.

```lua
local MyClass = setmetatable({}, BaseObject)
MyClass.ClassName = "MyClass"
MyClass.__index = MyClass

function MyClass.new(obj)
	local self = setmetatable(BaseObject.new(obj), MyClass)

	self._maid:GiveTask(workspace.ChildAdded:Connect(function(child)
		print("Child added:", child)
	end))

	return self
end

local instance = MyClass.new()
instance:Destroy() -- Cleans up the maid and everything it tracks
```

**Key API:** `BaseObject.new(obj?)`, `self._maid`, `self._obj`, `:Destroy()`

**When to use:** As the base class for any object that manages resources. Prefer this over writing your own constructor/destructor boilerplate.

## Binder

Automatically instantiates and manages a class for every Roblox Instance tagged with a specific [CollectionService](https://create.roblox.com/docs/reference/engine/classes/CollectionService) tag. When a tag is added, the class is created; when removed, it's destroyed.

```lua
local MyEffect = setmetatable({}, BaseObject)
MyEffect.ClassName = "MyEffect"
MyEffect.__index = MyEffect

function MyEffect.new(instance, serviceBag)
	local self = setmetatable(BaseObject.new(instance), MyEffect)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- React to the tagged instance
	self._maid:GiveTask(instance:GetPropertyChangedSignal("Color"):Connect(function()
		print("Color changed on", instance.Name)
	end))

	return self
end

-- In a BinderProvider or service:
local binder = Binder.new("MyEffect", require("MyEffect"), serviceBag)
binder:Start()

-- Tag an instance to bind it
binder:Bind(workspace.SomePart)

-- Query bound classes
local effect = binder:Get(workspace.SomePart)
```

**Key API:** `Binder.new(tag, class, ...)`, `:Start()`, `:Bind(instance)`, `:Get(instance)`, `:GetAll()`, `:GetClassAddedSignal()`, `:ObserveBrio(instance)`

**When to use:** When behavior should be attached to tagged Roblox Instances — NPCs, buttons, damage zones, visual effects, etc. The constructor receives `(instance, serviceBag)` so bound classes have full access to dependency injection.

## Rx (Observables)

A reactive stream library inspired by RxJS. Observables emit values over time; operators transform, filter, and combine them.

```lua
-- Create and transform
Rx.of(1, 2, 3):Pipe({
	Rx.map(function(x) return x * 2 end),
	Rx.where(function(x) return x > 2 end),
}):Subscribe(function(value)
	print(value) --> 4, 6
end)

-- Combine multiple sources
Rx.combineLatest({
	health = Rx.fromSignal(humanoid:GetPropertyChangedSignal("Health")),
	maxHealth = Rx.fromSignal(humanoid:GetPropertyChangedSignal("MaxHealth")),
}):Subscribe(function(data)
	print(data.health, data.maxHealth)
end)
```

**Key creation:** `Rx.of(...)`, `Rx.fromSignal(signal)`, `Rx.fromPromise(promise)`, `Rx.combineLatest({...})`

**Key operators (pass to `:Pipe()`):** `Rx.map(fn)`, `Rx.where(predicate)`, `Rx.flatMap(fn)`, `Rx.switchMap(fn)`, `Rx.tap(fn)`, `Rx.cache()`

**When to use:** For event-driven, time-varying data — combining multiple signals, filtering events, transforming streams. Prefer over manually wiring up connections when the logic involves more than one source.

## Brio

A lifetime-scoped wrapper for a value. When the Brio is killed, consumers know the value is no longer valid. Prevents use-after-free bugs in reactive streams.

```lua
local brio = Brio.new(workspace.SomePart)

brio:GetDiedSignal():Connect(function()
	print("Resource is no longer valid")
end)

if not brio:IsDead() then
	local part = brio:GetValue()
	print(part.Name)
end

brio:Kill() --> "Resource is no longer valid"
-- brio:GetValue() would now error
```

**Key API:** `Brio.new(...)`, `:GetValue()`, `:IsDead()`, `:Kill()` / `:Destroy()`, `:GetDiedSignal()`, `:ToMaid()`

**When to use:** When emitting objects from Observables that have a limited lifetime. Binder's `:ObserveBrio()` returns `Observable<Brio<T>>` — this is the canonical use case. Essential for safely passing resources through reactive pipelines.

### Three ways a Brio pipeline silently gives the wrong answer

These bite when a stream models "the current state of some replicated instances", where the consumer needs an answer at every moment — not just when things exist.

**Never emitting is not the same as emitting nil.** `RxInstanceUtils.observeLastNamedChildBrio` (and anything built on it) fires only once a matching child exists. Subscribe before the instance replicates and you get *nothing* — the subscriber can't tell "not there" from "not loaded yet" and renders whatever it had. End such a pipeline with `Rx.defaultsToNil`, which fires nil only when the source didn't already fire synchronously, so a present value never flickers through nil first.

**`Rx.EMPTY` as a switchMap fallback swallows the disappearance.** `Rx.switchMap(function(inst) return inst and Data:Observe(inst) or Rx.EMPTY end)` looks right, but `Rx.EMPTY` emits nothing at all — so when the instance goes away, the nil that `RxBrioUtils.emitOnDeath(nil)` worked to produce is dropped and the subscriber keeps stale data forever. Return `Rx.of(nil)`.

**`flatMapBrio` into `reduceToAliveList` appends instead of replaces.** Each emission of the inner observable becomes its own brio, bounded only by the *source* brio's lifetime, so a per-instance stream that re-emits (any attribute change) leaves the old value alive in the list alongside the new one. To build a live list of per-instance values, reduce to the alive *instances* first and `Rx.combineLatest` their value observables:

```lua
RxInstanceUtils.observeChildrenBrio(container):Pipe({
	RxBrioUtils.reduceToAliveList(), -- Brio<{ Instance }> -- one entry per live child
}),
RxBrioUtils.emitOnDeath(nil),
Rx.switchMap(function(instances)
	local observables = {}
	for index, instance in instances do
		observables[index] = SomeData:Observe(instance)
	end
	return Rx.combineLatest(observables) -- latest value per child, replaced not appended
end),
```

## Blend

Declarative UI framework that combines Rx observables with Roblox Instance creation. Properties can be static values or observables — when the observable emits, the UI updates automatically.

```lua
local visibility = Blend.State(0)

local gui = Blend.New "ScreenGui" {
	Parent = playerGui,

	Blend.New "Frame" {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = visibility, -- Reactively bound

		Blend.New "TextLabel" {
			Text = "Hello",
			Size = UDim2.fromOffset(200, 50),
		},
	},
}

maid:GiveTask(gui:Subscribe())

-- Changing state automatically updates the Frame
visibility.Value = 0.5
```

**Key API:** `Blend.New(className)({props})`, `Blend.State(value)`, `Blend.Computed(sources..., fn)`, `Blend.mount(instance, props)`, `Blend.Children`, `Blend.OnEvent(event)`, `Blend.OnChange(property)`

**When to use:** Building UI that needs to react to state changes. Replaces manual property updates and event wiring. Use `Blend.State` for mutable values and `Blend.Computed` for derived values.

## AdorneeData

Bridges Instance attributes and Lua data tables. Define a schema once (with defaults and validation), then read, write, and reactively observe those attributes on any Instance. Solves the problem of keeping attribute names, defaults, and validation in sync across your codebase.

```lua
-- Define the schema (typically in its own module)
local MyData = AdorneeData.new({
	IsEnabled = true,       -- boolean, default true
	Speed = 20,             -- number, default 20
	Label = "default",      -- string, default "default"
})

-- Initialize attributes on an instance (sets defaults if not already present)
MyData:InitAttributes(someInstance)

-- Read all attributes as a table
local data = MyData:Get(someInstance)
print(data.IsEnabled, data.Speed) --> true, 20

-- Write attributes
MyData:Set(someInstance, { Speed = 50 })

-- Create a reactive wrapper — each field becomes a ValueObject
local wrapper = MyData:Create(someInstance)
wrapper.Speed.Value = 100                          -- write
print(wrapper.IsEnabled.Value)                     -- read

maid:GiveTask(wrapper.Speed:Observe():Subscribe(function(speed)
	print("Speed changed to", speed)               -- reacts to attribute changes
end))
```

**Key API:** `AdorneeData.new(prototype)`, `:Get(instance)`, `:Set(instance, data)`, `:InitAttributes(instance)`, `:Create(instance)` (reactive wrapper), `:Observe(instance)`, `:IsData(data)` / `:IsStrictData(data)` (validation)

**When to use:** When you need replicated configuration on Instances — physics parameters, toggles, tuning values. Attributes replicate automatically over the network; AdorneeData wraps them with defaults, validation, and Rx observability. Common in ragdoll, rogue-properties, and other systems that configure Instances at runtime.

## TieDefinition

Declares a loose-coupling interface contract that can be implemented via nested Instances. Enables cross-realm (client/server) communication without direct module references. The most advanced pattern — prefer Binder for simpler cases.

```lua
-- Define the interface
local DoorDef = TieDefinition.new("Door", {
	Open = TieDefinition.Types.METHOD,
	Close = TieDefinition.Types.METHOD,
	IsOpen = TieDefinition.Types.PROPERTY,
})

-- Implement it on an Instance (server)
local doorImpl = {
	Open = function() ... end,
	Close = function() ... end,
	IsOpen = false,
}
DoorDef:Implement(doorInstance, doorImpl)

-- Consume it (client or server)
local door = DoorDef:Find(doorInstance)
if door then
	door:Open()
end
```

**Key API:** `TieDefinition.new(name, members)`, `:Implement(instance, table)`, `:Find(instance)`, `:Observe(instance)`, `TieDefinition.Types.METHOD | SIGNAL | PROPERTY`

**When to use:** When you need optional or pluggable interfaces — particularly across client/server boundaries or for plugin systems where the implementer shouldn't need to know about the consumer.

## Remoting observables

[Remoting](/api/Remoting) wraps RemoteEvents and RemoteFunctions so a service can declare its network surface as members rather than hand-managed Instances. Alongside the event and method members it can carry observable streams: the server binds a factory, the client subscribes, and values flow for as long as the client stays subscribed.

```lua
-- Server
remoting:BindObservable("Health", function(player, entityId)
	return observeHealth(player, entityId)
end)

-- Client
maid:GiveTask(remoting:Observe("Health", entityId):Subscribe(print))

-- Or through member syntax, which reads better at the call site
remoting.Health:BindObservable(function(player, entityId) ... end)
maid:GiveTask(remoting.Health:Observe(entityId):Subscribe(print))
```

The factory runs once per subscription, so it can vary the stream by player and by the arguments the client passed. The server tears the stream down when the client unsubscribes, when the source completes or fails, when the player leaves, or when the remoting is destroyed — the client's subscription completes in that last case rather than hanging.

Under the hood each observable member reserves one extra remote event named `<Member>__Observe`. A RemoteEvent is full duplex, so that single instance carries subscribe and unsubscribe up and emissions down.

**Two ways this differs from a local observable:**

**It cannot emit synchronously on subscribe.** Most Nevermore observables fire an initial value during `:Subscribe()`; this one can't, because the first value is at least a round trip away. Anything that assumes a synchronous first emission — a Blend binding, a `Rx.combineLatest` that mixes local and remote sources — will sit empty until the value lands. Give it a starting value with `Rx.defaultsTo` when the consumer can't tolerate that gap.

**It is cold, and each subscription costs a stream.** Two `:Subscribe()` calls on the same observable open two server-side subscriptions and produce two streams of packets. That is correct Rx semantics but a real network bill, so pipe through `Rx.share()` when several consumers want the same values.

**When to use:** When the client needs a live view of server state rather than a one-shot answer. For a single value, `PromiseInvokeServer` is cheaper and simpler.

## How the patterns fit together

These patterns compose naturally:

1. **Maid + BaseObject** — The foundation. Every class extends BaseObject to get automatic cleanup.
2. **Binder + BaseObject** — Create a class extending BaseObject, bind it to tagged Instances via Binder.
3. **Rx + Maid** — Subscribe to observables, store subscriptions in maids for cleanup.
4. **Brio in Observables** — When emitting objects with lifetimes from Rx streams, wrap them in Brio.
5. **Blend + Rx** — Blend properties accept observables directly, making UI reactive.
6. **ServiceBag + Binder** — Services create and manage binders; binders receive ServiceBag for dependency injection.
7. **AdorneeData + Binder** — Binder creates a class per tagged Instance; AdorneeData reads/observes configuration attributes on that Instance.
8. **Remoting + Rx** — Remoting carries observables across the client/server boundary, so a server-side Rx pipeline can drive client UI directly.
