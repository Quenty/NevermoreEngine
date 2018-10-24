--- Tweens numbers
-- @classmod NumberPropertyTweener

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spring = require("Spring")

local NumberPropertyTweener = {}
NumberPropertyTweener.ClassName = "NumberPropertyTweener"
NumberPropertyTweener.__index = NumberPropertyTweener

function NumberPropertyTweener.new(object, property)
	local self = setmetatable({}, NumberPropertyTweener)

	self._object = object or error("No object")
	self._property = property or error("No property")
	self._currentState = Spring.new(self._object[self._property])
	self._currentState.Speed = 20

	return self
end

function NumberPropertyTweener:SetSpeed(speed)
	self._speed = speed or error("No speed")
end

function NumberPropertyTweener:Tween(target)
	self._currentState.Target = target
end

function NumberPropertyTweener:Update()
	local current = self._currentState.Value

	local stillUpdating = math.abs(current - self._currentState.Target) >= 1e-3
	if not stillUpdating then
		current = self._currentState.Target
	end

	self._object[self._property] = current
	return stillUpdating
end

return NumberPropertyTweener