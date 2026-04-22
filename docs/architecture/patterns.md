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

**When to use:** Any time you create connections, spawn threads, or instantiate objects that need cleanup. Almost every class uses one.

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

## How the patterns fit together

These patterns compose naturally:

1. **Maid + BaseObject** — The foundation. Every class extends BaseObject to get automatic cleanup.
2. **Binder + BaseObject** — Create a class extending BaseObject, bind it to tagged Instances via Binder.
3. **Rx + Maid** — Subscribe to observables, store subscriptions in maids for cleanup.
4. **Brio in Observables** — When emitting objects with lifetimes from Rx streams, wrap them in Brio.
5. **Blend + Rx** — Blend properties accept observables directly, making UI reactive.
6. **ServiceBag + Binder** — Services create and manage binders; binders receive ServiceBag for dependency injection.
7. **AdorneeData + Binder** — Binder creates a class per tagged Instance; AdorneeData reads/observes configuration attributes on that Instance.
