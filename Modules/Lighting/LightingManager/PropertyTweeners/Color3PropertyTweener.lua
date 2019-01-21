--- Tweens color3s by HSV
-- @classmod Color3PropertyTweener

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Spring = require("Spring")

local Color3PropertyTweener = {}
Color3PropertyTweener.ClassName = "Color3PropertyTweener"
Color3PropertyTweener.__index = Color3PropertyTweener

function Color3PropertyTweener.new(object, property)
	local self = setmetatable({}, Color3PropertyTweener)

	self._object = object or error("No oject")
	self._property = property or error("No property")

	local color = self._object[self._property]
	if typeof(color) ~= "Color3" then
		error(("Bad property %q, expected Color3, got %q"):format(self._property, typeof(color)))
	end
	local h, s, v = Color3.toHSV(color)
	self._currentState = Spring.new(Vector3.new(h, s, v))
	self._currentState.Speed = 20

	return self
end

function Color3PropertyTweener:SetSpeed(speed)
	self._currentState.Speed = speed or error("No speed")
end

function Color3PropertyTweener:Tween(target)
	assert(typeof(target) == "Color3", "Target must be a Color3")

	local h, s, v = Color3.toHSV(target)
	self._currentState.Target = Vector3.new(h, s, v)
end

function Color3PropertyTweener:Update()
	local current = self._currentState.Value
	local h, s, v = current.x, current.y, current.z

	local stillUpdating = (current - self._currentState.Target).Magnitude >= 1e-3
	if not stillUpdating then
		local target = self._currentState.Target
		h, s, v = target.x, target.y, target.z
	end
	self._object[self._property] = Color3.fromHSV(h, s, v)

	return stillUpdating
end

return Color3PropertyTweener
