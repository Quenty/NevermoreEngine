## Binder
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

Binders bind a class to Roblox Instance

## Installation
```
npm install @quenty/binder --save
```

## Usage

```lua
-- Setup a class!
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(robloxInstance)
	print("New tagged instance of ", robloxInstance")
	return setmetatable({}, MyClass)
end

function MyClass:Destroy()
	print("Cleaning up")
	setmetatable(self, nil)
end

-- bind to every instance with tag of "TagName"!
local binder = Binder.new("TagName", MyClass)
binder:Start() -- listens for new instances and connects events
```

## API

### `Binder.new(tagName, constructor)`
Creates a new binder object.

### `Binder.isBinder(value)`
Retrieves whether or not its a binder

### `Binder:Start()`
Listens for new instances and connects to the GetInstanceAddedSignal() and removed signal!

### `Binder:GetTag()`
Returns the tag name that the binder has

### `Binder:GetConstructor()`
Returns whatever was set for the construtor. Used for meta-analysis of the binder, such as extracting new

### `Binder:ObserveInstance(inst, callback)`
Fired when added, and then after removal, but before destroy!

### `Binder:GetClassAddedSignal()`
Returns a new signal that will fire whenever a class is bound to the binder

### `Binder:GetClassRemovingSignal()`
Returns a new signal that will fire whenever a class is removed from the binder

### `Binder:GetAll()`
Returns all of the classes in a new table

```lua
local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

-- Update every bird every frame
RunService.Stepped:Connect(function()
	for _, bird in pairs(birdBinder:GetAll()) do
		bird:Update()
	end
end)

```
### `Binder:GetAllSet()`
Faster method to get all items in a binder

NOTE: Do not mutate this set directly

```lua
local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

-- Update every bird every frame
RunService.Stepped:Connect(function()
	for bird, _ in pairs(birdBinder:GetAllSet()) do
		bird:Update()
	end
end)

birdBinder:Start()
```

### `Binder:Bind(inst)`
Binds an instance to this binder using collection service and attempts to return it if it's bound properly. See BinderUtils.promiseBoundClass() for a safe way to retrieve it.

NOTE: Do not assume that a bound object will be retrieved

### `Binder:Unbind(inst)`
Unbinds the instance by removing the tag

### `Binder:BindClient(inst)`
See :Bind(). Acknowledges the risk of doing this on the client. Using this acknowledges that we're intentionally binding on a safe client object, i.e. one without replication. If another tag is changed on this instance, this tag will be lost/changed.

### `Binder:UnbindClient(inst)`
See Unbind(), acknowledges risk of doing this on the client.

### `Binder:Get(inst)`
Returns a version of the clas

### `Binder:Promise(inst, cancelToken)`

### `Binder:Destroy()`
Cleans up all bound classes, and disconnects all events

## Changelog

### 1.0.0
Initial release

## 0.0.2

- Removed BoundLinkCollection and promiseBoundLinkedClass (moved to `@quenty/boundlinkutils`)

## 0.0.1

- Add RxBinderUtils
- Add RxBinderGroupUtils
- Add changelog
- Add documentation

## 0.0.0

Initial commit