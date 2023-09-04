--[=[
	Brios wrap a value (or tuple of values) and are used to convey the lifetime of that
	object. The brio is better than a maid, by providing the following constraints:

	- Can be in 2 states, dead or alive.
	- While alive, can retrieve values.
	- While dead, retrieving values is forbidden.
	- Died will fire once upon death.

	Brios encapsulate the "lifetime" of a valid resource. Unlike a maid, they
	- Can only die once, ensuring duplicate calls never occur.
	- Have less memory leaks. Memory leaks in maids can occur when use of the maid occurs
	  after the cleanup of the maid has occured, in certain race conditions.
	- Cannot be reentered, i.e. cannot retrieve values after death.

	:::info
	Calling `brio:Destroy()` or `brio:Kill()` after death does nothing. Brios cannot
	be resurrected.
	:::

	Brios are useful for downstream events where you want to emit a resource. Typically
	brios should be killed when their source is killed. Brios are intended to be merged
	with downstream brios so create a chain of reliable resources.

	```lua
	local brio = Brio.new("a", "b")
	print(brio:GetValue()) --> a b
	print(brio:IsDead()) --> false

	brio:GetDiedSignal():Connect(function()
		print("Hello from signal!")
	end)
	brio:ToMaid():GiveTask(function()
		print("Hello from maid cleanup!")
	end)
	brio:Kill()
	--> Hello from signal!
	--> Hello from maid cleanup!

	print(brio:IsDead()) --> true
	print(brio:GetValue()) --> ERROR: Brio is dead
	```

	## Design philosophy

	Brios are designed to solve this issue where we emit an object with a lifetime associated with it from an
	Observable stream. This resource is only valid for some amount of time (for example, while the object is
	in the Roblox data model).

	In order to know how long we can keep this object/use it, we wrap the object with a Brio, which denotes
	 the lifetime of the object.

	Modeling this with pure observables is very tricky because the subscriber will have to also monitor/emit
	a similar object with less clear conventions. For example  an observable that emits the object, and then nil on death.

	@class Brio
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local GoodSignal = require("GoodSignal")

local Brio = {}
Brio.ClassName = "Brio"
Brio.__index = Brio

--[=[
	Returns whether a value is a Brio.

	```lua
	print(Brio.isBrio("yolo")) --> false
	```
	@param value any
	@return boolean
]=]
function Brio.isBrio(value)
	return type(value) == "table" and value.ClassName == "Brio"
end

--[=[
	Constructs a new Brio.

	```lua
	local brio = Brio.new("a", "b")
	print(brio:GetValue()) --> a b
	```

	@param ... any -- Brio values
	@return Brio
]=]
function Brio.new(...) -- Wrap
	return setmetatable({
		_values = table.pack(...);
	}, Brio)
end

--[=[
	Constructs a new brio that will cleanup afer the set amount of time

	@since 3.6.0
	@param time number
	@param ... any -- Brio values
	@return Brio
]=]
function Brio.delayed(time, ...)
	local brio = Brio.new(...)
	task.delay(time, function()
		brio:Kill()
	end)
	return brio
end

--[=[
	Gets a signal that will fire when the Brio dies. If the brio is already dead
	calling this method will error.

	:::info
	Calling this while the brio is already dead will throw a error.
	:::

	```lua
	local brio = Brio.new("a", "b")
	brio:GetDiedSignal():Connect(function()
		print("Brio died")
	end)

	brio:Kill() --> Brio died
	brio:Kill() -- no output
	```

	@return Signal
]=]
function Brio:GetDiedSignal()
	if self:IsDead() then
		error("Brio is dead")
	end

	if self._diedEvent then
		return self._diedEvent
	end

	self._diedEvent = GoodSignal.new()
	return self._diedEvent
end

--[=[
	Returns true is the brio is dead.

	```lua
	local brio = Brio.new("a", "b")
	print(brio:IsDead()) --> false

	brio:Kill()

	print(brio:IsDead()) --> true
	```

	@return boolean
]=]
function Brio:IsDead()
	return self._values == nil
end

--[=[
	Throws an error if the Brio is dead.

	```lua
	brio.DEAD:ErrorIfDead() --> ERROR: [Brio.ErrorIfDead] - Brio is dead
	```
]=]
function Brio:ErrorIfDead()
	if not self._values then
		error("[Brio.ErrorIfDead] - Brio is dead")
	end
end

--[=[
	Constructs a new Maid which will clean up when the brio dies.
	Will error if the Brio is dead.

	:::info
	Calling this while the brio is already dead will throw a error.
	:::

	```lua
	local brio = Brio.new("a")
	local maid = brio:ToMaid()
	maid:GiveTask(function()
		print("Cleaning up!")
	end)
	brio:Kill() --> Cleaning up!
	```

	@return Maid
]=]
function Brio:ToMaid()
	assert(self._values ~= nil, "Brio is dead")

	local maid = Maid.new()

	maid:GiveTask(self:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return maid
end

function Brio:ToMaidAndValue()
	return self:ToMaid(), self:GetValue()
end

--[=[
	If the brio is not dead, will return the values unpacked from the brio.

	:::info
	Calling this while the brio is already dead will throw a error. Values should
	not be used past the lifetime of the brio, and can be considered invalid.
	:::

	```lua
	local brio = Brio.new("a", 1, 2)
	print(brio:GetValue()) --> "a" 1 2
	brio:Kill()

	print(brio:GetValue()) --> ERROR: Brio is dead
	```

	@return any
]=]
function Brio:GetValue()
	assert(self._values, "Brio is dead")

	return unpack(self._values, 1, self._values.n)
end

--[=[
	Returns the packed values from table.pack() format

	@since 3.6.0
	@return { n: number, ... T }
]=]
function Brio:GetPackedValues()
	assert(self._values, "Brio is dead")

	return self._values
end

--[=[
	Kills the Brio.

	:::info
	You can call this multiple times and it will not error if the brio is dead.
	:::

	```lua
	local brio = Brio.new("hi")
	print(brio:GetValue()) --> "hi"
	brio:Kill()

	print(brio:GetValue()) --> ERROR: Brio is dead
	```
]=]
function Brio:Destroy()
	if not self._values then
		return
	end

	self._values = nil

	if self._diedEvent then
		self._diedEvent:Fire()
		self._diedEvent:Destroy()
		self._diedEvent = nil
	end
end

--[=[
	Alias for Destroy.
	@method Kill
	@within Brio
]=]
Brio.Kill = Brio.Destroy

--[=[
	An already dead brio which may be used for identity purposes.

	```lua
	print(Brio.DEAD:IsDead()) --> true
	```

	@prop DEAD Brio
	@within Brio
]=]
Brio.DEAD = Brio.new()
Brio.DEAD:Kill()

return Brio