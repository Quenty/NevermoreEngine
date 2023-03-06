# How ServiceBag works

ServiceBag provides services and helps with game or plugin initialization.

## tl;dr

ServiceBag is like a `game` in Roblox. You can retrieve services from it, and
it will ensure the service exists and is initialized. This will bootstrap any
other dependent dependencies.

## Why understanding ServiceBag is important

Nevermore tries to be a collection of libraries that can be plugged together,
and not exist as a set framework that forces specific design decisions. While
there are certainly some design patterns these libraries will guide you to,
you shouldn't necessarily feel forced to operate within these set of
scenarios.

That being said, in order to use certain services, like `CmdrService` or
permission service, you need to be familiar with `ServiceBag`.

If you're making a game with Nevermore, serviceBag solves a wide variety
of problems with the lifecycle of the game, and is fundamental to the fast
iteration cycle intended with Nevermore.

Many prebuilt systems depend upon ServiceBag and expect to be initialized
through ServiceBag.

## Is ServiceBag good?

ServiceBag supports multiple production games. ServiceBag allows for
functionality that isn't otherwise available in traditional programming
techniques in Roblox. More specifically:

* Your games initialization can be controlled specifically
* Recursive initialization (transient dependencies) will not cause refactoring
  requirements at higher level games. Lower-level packages can add additional
  dependencies without fear of breaking their downstream consumers.
* Life cycle management is maintained in a standardized way
* You can technically have multiple copies of your service running at once. This
  is useful for plugins and stuff.

While serviceBag isn't required to make a quality Roblox game, and may seem
confusing at first, ServiceBag or an equivalent lifecycle management system
and dependency injection system is a really good idea.

## What ServiceBag tries to achieve

ServiceBag does service dependency injection and initialization. These words
may be unfamiliar with you. Dependency injection is the process of retrieving
dependencies instead of constructing them in an object. Lifecycle management is 
the process of managing the life of services, which often includes the game.

For the most part, ServiceBag is interested in the initialization of services
within your game, since most services will not deconstruct. This allows for
services that cross-depend upon each other, for example, if service A and
service B both need to know about each other, serviceBag will allow for this
to happen. A traditional module script will not allow for a circular dependency
in the same way.

ServiceBag achieves circular dependency support by having a lifecycle hook
system.

## What is a service

A service is a singleton, that is, a module of which exactly one exists. This
is oftentimes very useful, especially in de-duplicating behavior. Services
are actually something you should be familiar with on Roblox, if you've been
programming on Roblox for a while.

```lua
-- Workspace is an example of a service in Roblox
local workspace = game:GetService("Workspace")
```

It's useful to define our own services. A canonical service in Nevermore looks
like this.

```lua
--[=[
	A canonical service in Nevermore
	@class ServiceName
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local ServiceName = {}
ServiceName.ServiceName = "ServiceName"

function ServiceName:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("OtherService"))
end

function ServiceName:Start()
	print("Started")
end

function ServiceName:MyMethod()
	print("Hello")
end

function ServiceName:Destroy()
	self._maid:DoCleaning()
end

return ServiceName
```

## Service LifeCycle methods

There are 3 methods in a service that are precoded in a `ServiceBag`. These
are as follows

* `Init(serviceBag)` - Initializes the service. If any more services need to
  be initialized then this should also get those services at this time.
* `Start()` - Called when the game starts. Cannot yield. Starts actual
  behavior, including logic that depends on other services.
* `Destroy()` - Cleans up the existing service

All three of these services are optional. However, if you want to have
services bootstrapped that this service depends upon, then you should
do this in `Init`

### What happens on ServiceBag:Init()

When init happens, ServiceBag will called :Init() on any service that has been
retrieved. If any of these services retrieve additional services then these
will also be initialized and stored in the ServiceBag. Notably ServiceBag
will not use the direct memory of the service, but instead create a new table
and store the state in the ServiceBag itself.


```lua
local serviceBag = ServiceBag.new()
serviceBag:GetService(packages.MyModuleScript)

serviceBag:Init()
serviceBag:Start()
```

:::info
ServiceBag will not allow your service to yield. This is to prevent a service
from delaying your entires game start. If you need to yield, do work in start
or export your API calls as promises. See Cmdr for a good example of how this
works.
:::

Retrieving a service from inside of :Init() that service is guaranteed to be
initialized. Services are started in the order they're initialized.

```lua
function MyService:Init(serviceBag)
	self._myOtherService = serviceBag:GetService(require("MyOtherService"))

	-- Services are guaranteed to be initialized if you retrieve them in an
	-- init of another service, assuming that :Init() is done via ServiceBag.
	self._myOtherService:Register(self)
end
```


When init is over, no more services can be added to the serviceBag. 

### What happens on ServiceBag:Start()

When Start happens the serviceBag will go through each of its services
that have been initialized and attempt to call the :Start() method on it
if it exists.

This is a good place to use other services that you may have needed as they
are guaranteed to be initialized. However, you can also typically assume
initialization is done in the :Init() method. However, sometimes you may
assume initialization but no start.

### What happens on ServiceBag:Destroy()

When :Destroy() is called, all services are destroyed. The serviceBag will
call `Destroy()` on services if they offer it. This functionality is useful
if you're initializing services during hoarcekat stories or unit tests.


## How do I retrieve services

You retrieve a service by calling `GetService`. `GetService` takes in a table.
If you pass it a module script, the service bag will require the module
script and use the resulting definition as the service definition.

```lua
local serviceBag = ServiceBag.new()

local myService = serviceBag:GetService(packages.MyModuleScript)

serviceBag:Init()
serviceBag:Start()
```

As soon as you retrieve the service you should be able to call methods on it.
However, the state of the service will be whatever it is before init or start.
You may want to call :Init() or :Start() before using methods on the service. 


## Why can't you pass in arguments into :GetService()

Service configuration is not offered in the retrieval of :GetService() because
inherently we don't want unstable or random behavior in our games. If we had
arguments in ServiceBag then you better hope that your initialization order
gets to configure the first service first. Otherwise, if another package adds
a service in the future then you will have different behavior.

### How do you configure a service instead of arguments?

Typically, you can configure a service by calling a method after :Init() is
called, or after :Start() is called.

### Should services have side effects when initialized or started?

Services should typically not have side effects when initialized or started.

## Dependency injection

ServiceBag is also effectively a dependency injection system. In this system
you can of course, inject services into other services.

For this reason, we inject the ServiceBag into the actual package itself.

```lua
-- Service bag injection
function CarCommandService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
end
```

### Dependency injection in objects

If you've got an object, it's typical you may need a service there

```lua
--[=[
	@class MyClass
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local MyClass = setmetatable({}, BaseObject)
MyClass.ClassName = "MyClass"
MyClass.__index = MyClass

function MyClass.new(serviceBag)
	local self = setmetatable(BaseObject.new(), MyClass)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cameraStackService = self._serviceBag:GetService(require("CameraStackService"))
	
	return self
end

return MyClass
```

It's very common to pass or inject a service bag into the service

### Dependency injection in binders

Binders explicitly support dependency injection. You can see that a
binderProvider here retrieves a serviceBag (or any argument you want)
and then the binder retrieves the extra argument.

```lua
return BinderProvider.new(script.Name, function(self, serviceBag)
	-- ...
	self:Add(Binder.new("Ragdoll", require("RagdollClient"), serviceBag))
	-- ...
end)
```

Binders then will get the `ServiceBag` as the second argument.

```lua

function Ragdoll.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdoll)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	-- Use services here.

	return self
end
```

## Memory management - ServiceBag will annotate stuff for you

ServiceBag will automatically annotate your service with a memory profile name
so that it is easy to track down which part of your codebase is using memory.
This fixes a standard issue with diagnosing memory in a single-script
architecture.

## Using ServiceBag with stuff that doesn't have access to ServiceBag

If you're working with legacy code, or external code, you may not want
to pass an initialized ServiceBag around. This will typically make the code
less testable, so take this with caution, but you can typically use a few
helper methods to return fully initialized services instead of having to
retrieve them through the servicebag.

```lua
local function getAnyModule(module)
	if serviceBag:HasService(module) then
		return serviceBag:GetService(module)
	else
		return module
	end
end
```

It's preferably your systems interop with ServiceBag directly as ServiceBag
provides more control, better testability, and more clarity on where things
are coming from.
