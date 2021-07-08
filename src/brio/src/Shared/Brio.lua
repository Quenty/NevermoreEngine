--- Brios are wrap a value and provide the following constraints
--[[
- Can be in 2 states, dead or alive
- While alive, can retrieve values
- While dead, retrieving values is forbidden
- Died will fire once upon death

Brios encapsulate the "lifetime" of a valid resource. Unlike a maid, they
- Can only die once
- Have less memory leaks
- Cannot be reentered

Calling :Destroy() or :Kill() after death does nothing. Brios cannot be resurrected.

Useful for downstream events where you want to emit a resource. Typically
brios should be killed when their source is killed.

Brios are intended to be merged with downstream brios so create a chain of reliable
resources.

Anything may "kill" a brio by calling :Destroy() or :Kill().
]]
-- @classmod Brio

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local Brio = {}
Brio.ClassName = "Brio"
Brio.__index = Brio

function Brio.isBrio(value)
	return type(value) == "table" and value.ClassName == "Brio"
end

function Brio.new(...) -- Wrap
	return setmetatable({
		_values = table.pack(...);
	}, Brio)
end

function Brio:GetDiedSignal()
	if self:IsDead() then
		error("Already dead")
	end

	if self._diedEvent then
		return self._diedEvent.Event
	end

	self._diedEvent = Instance.new("BindableEvent")
	return self._diedEvent.Event
end

function Brio:IsDead()
	return self._values == nil
end

function Brio:ErrorIfDead()
	if not self._values then
		error("[CancelToken.ErrorIfDead] - Dead")
	end
end

function Brio:ToMaid()
	assert(self._values ~= nil, "Dead")

	local maid = Maid.new()

	maid:GiveTask(self:GetDiedSignal():Connect(function()
		maid:DoCleaning()
	end))

	return maid
end

function Brio:GetValue()
	assert(self._values)

	return unpack(self._values, 1, self._values.n)
end

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
Brio.Kill = Brio.Destroy

-- Setup dead
Brio.DEAD = Brio.new()
Brio.DEAD:Kill()

return Brio