---
-- @classmod Brio
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")

local Brio = {}
Brio.ClassName = "Brio"
Brio.__index = Brio

function Brio.isBrio(value)
	return type(value) == "table" and value.ClassName == "Brio"
end

function Brio.new(...) -- Wrap
	return setmetatable({
		_values = table.pack(...);
		Died = Signal.new();
	}, Brio)
end

function Brio:IsDead()
	return self._values == nil
end

function Brio:GetValue()
	assert(self._values)

	return unpack(self._values, 1, self._values.n)
end

function Brio:Destroy()
	assert(self._values)

	self._values = nil
	self.Died:Fire()
	self.Died:Destroy()
	self.Died = nil
end
Brio.Kill = Brio.Destroy

Brio.DEAD = Brio.new():Destroy()

return Brio