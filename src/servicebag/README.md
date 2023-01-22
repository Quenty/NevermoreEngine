## ServiceBag
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Service providing mechanisms for Nevermore

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/ServiceBag">View docs →</a></div>

## Installation
```
npm install @quenty/servicebag --save
```

## Goals
- Remove requirement for many services to be loaded
- Make installing new modules really easy
- Make testing easier
- Reduce maintaince costs
- Explicitly declare service pattern
- Force declaration of service usage
- Make it easy to trace service dependencies

## Requirements

- Initialize dependent services using `:Init()`
- Start dependent services using `:Start()`
- Retrieve services is easy
- Don't have to list off every service in the game
- Services don't load until we ask them to
- Circular dependencies allowed

## Like-to-have

- Dependency injection for tests
- Works with type system `GetService<IService>()`
- Async initialization (return promises instead of blocking)
- Dependency graph safe (i.e. recursive service requirement )
- Services are protected from another service erroring

## Stretch goals
- Handles services for actors (remove global code)

## Ideas
- Inject a ServiceBag

## Rules

1. Each service will be identified by its module
2. Each service will be initialized once
3. If we require a service, we will not have to declare subservices

```lua
-- Main script
local serviceBag = require("ServiceBag").new()

serviceBag:AddService(require("TransparencyService"))

serviceBag:Init()
serviceBag:Start()
```

```lua
-- Other script
local TransparencyService = require("TransparencyService") -- force declaration at top

local TestClass = {}
TestClass.ClassName = "TestClass"
TestClass.__index = TestClass

function TestClass.new(serviceBag)
	local self = setmetatable({}, TestClass)

	self._serviceProvider = assert(serviceBag, "No serviceBag")

	self._transparencyService = self._serviceProvider:GetRequiredService(TransparencyService)
	
	return self
end

return TestClass
```

```lua
local DialogPane = setmetatable({}, BasicPane)
DialogPane.ClassName = "DialogPane"
DialogPane.__index = DialogPane

function DialogPane.new(serviceBag)
  local self = setmetatable(BasicPane.new(serviceBag:GetService(DialogTemplatesClient):Clone("DialogPaneTemplate")), DialogPane)

  self._theme = Instance.new("StringValue")
  self._theme.Value = "Light"
  self._maid:GiveTask(self._theme)

  self._dialogInput = DialogInput.new()
  self._maid:GiveTask(self._dialogInput)

```