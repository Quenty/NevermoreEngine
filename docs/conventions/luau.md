---
title: Luau Conventions
sidebar_position: 1
---

# Luau Conventions

This guide covers how to write Luau code in this project. All code uses `--!strict` mode, and every file follows consistent patterns for class structure, typing, and naming. These conventions are shared with the Raven companion repo.

## Why strict typing?

Luau's type inference doesn't handle metatables well. When you write `setmetatable({}, MyClass)`, Luau can't automatically infer the fields you'll assign to `self` in the constructor. Without explicit type annotations, the type checker either flags legitimate code or loses track of types entirely.

The project uses an explicit typing pattern that tells the type checker exactly what fields exist on each class. This is more verbose than untyped Lua, but it catches real bugs — misspelled field names, wrong argument types, missing nil checks — at edit time instead of at runtime in a live game.

## Class structure

Every class follows this structure:

### 1. File header and requires

```lua
--!strict
--[=[
    @class MyClass
]=]

local require = require(script.Parent.loader).load(script)

-- Requires are auto-sorted by stylua
local BaseObject = require("BaseObject")
local ServiceBag = require("ServiceBag")
```

The `require(script.Parent.loader).load(script)` line enables the custom module resolution system. Every file needs it.

### 2. Class table setup

```lua
local MyClass = setmetatable({}, BaseObject)
MyClass.ClassName = "MyClass"
MyClass.__index = MyClass
```

`ClassName` is a static field used for debugging and identification. Always matches the class name.

### 3. Export type declaration

Place this after the class table setup, before the constructor. It tells the type checker what fields exist on instances of this class:

```lua
export type MyClass =
    typeof(setmetatable(
        {} :: {
            _obj: Instance,
            _serviceBag: ServiceBag.ServiceBag,
            _enabled: ValueObject.ValueObject<boolean>,
            -- list ALL instance fields with their types
        },
        {} :: typeof({ __index = MyClass })
    ))
    & BaseObject.BaseObject  -- intersection with parent type
```

The `& ParentClass.ParentClass` intersection gives you access to inherited fields like `_maid` and `_obj`.

### 4. Constructor

```lua
function MyClass.new(obj: Instance, serviceBag: ServiceBag.ServiceBag): MyClass
    local self: MyClass = setmetatable(BaseObject.new(obj) :: any, MyClass)

    self._serviceBag = assert(serviceBag, "No serviceBag")
    -- Initialize fields...

    return self
end
```

The `:: any` cast on `setmetatable` is necessary because Luau can't verify the metatable transformation preserves the type. This is one of the few places `:: any` is acceptable.

### 5. Methods — use dot syntax

Strict mode requires explicit `self` typing. Use dot syntax (not colon syntax) for method definitions:

```lua
-- Correct: dot syntax with explicit self type
function MyClass.GetEnabled(self: MyClass): boolean
    return self._enabled.Value
end

-- Wrong: colon syntax loses self type in strict mode
function MyClass:GetEnabled(): boolean
    return self._enabled.Value  -- type error: _enabled not known
end
```

Callers still use colon syntax (`myObj:GetEnabled()`). Only the definition changes.

### 6. Binder return

When a class is bound to Roblox instances via a tag:

```lua
return Binder.new("MyTag", MyClass :: any) :: Binder.Binder<MyClass>
```

The `:: any` on the class and the `:: Binder.Binder<MyClass>` on the return give the binder system proper generic typing.

## Common type imports

These are the types you'll use most often:

| Type | Package | Description |
|------|---------|-------------|
| `ServiceBag.ServiceBag` | ServiceBag | Dependency injection container |
| `Observable.Observable<T>` | Rx | Reactive observable stream |
| `Brio.Brio<T>` | Brio | Value with lifecycle (value + cleanup) |
| `Maid.Maid` | Maid | Resource cleanup tracker |
| `ValueObject.ValueObject<T>` | ValueObject | Reactive value container |
| `Signal.Signal<T>` | Signal | Event signal |
| `BaseObject.BaseObject` | BaseObject | Base class type |
| `Binder.Binder<T>` | Binder | Tag-based instance binder |
| `AttributeValue.AttributeValue<T>` | AttributeValue | Attribute-backed reactive value |

## Naming conventions

- **Private fields**: `_` prefix (`self._maid`, `self._enabled`, `self._processAsync`)
- **Public signals**: PascalCase (`self.HumanoidEntered`, `self.PlayerCount`)
- **Methods**: PascalCase (`GetEnabled`, `ObservePlayersBrio`)
- **Observable methods**: `Observe*` prefix, often with `Brio` suffix (`ObservePlayersBrio`)
- **ClassName**: Always matches the class name exactly

## Coding conventions

- **Require pattern**: `local require = require(script.Parent.loader).load(script)` at the top of every file
- **Requires sorted**: stylua sorts requires alphabetically (`[sort_requires] enabled = true`)
- **Assert serviceBag**: `self._serviceBag = assert(serviceBag, "No serviceBag")` in constructors
- **Moonwave docstrings**: `--[=[ @class ClassName ]=]` at the top of each file
- **Conventional commits**: `feat(scope):`, `fix(scope):`, `chore(scope):`, etc.
- **Commit messages describe impact, not reasoning**: Keep them short. e.g. `fix(localizedtextutils): make translationArgs optional`
- **Squash before pushing**: Rebase and squash into a single cohesive commit before pushing

## When to use `:: any` casts

`:: any` is a last resort. Acceptable uses:
- `setmetatable(ParentClass.new(obj) :: any, MyClass)` — metatable transformation in constructors
- `Binder.new("Tag", MyClass :: any)` — binder registration
- Rx `Pipe` chains where intermediate types can't be inferred
- `Signal.new() :: any` — when the signal type would be too complex to annotate inline

**Prefer fixing upstream types** over casting. If a type is wrong, fix it in the source package.
