--- Helps round angles versus target angles
-- @module IKAngleCalculator

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AccelTween = require("AccelTween")

local IKAngleCalculator = {}
IKAngleCalculator.ClassName = "IKAngleCalculator"
IKAngleCalculator._min = math.pi/32
IKAngleCalculator._bounceRange = math.pi/32
IKAngleCalculator._bounceAmount = math.pi/32

function IKAngleCalculator.new(animationTime)
	local self = setmetatable({}, IKAngleCalculator)

	self._tweener = AccelTween.new(animationTime or 16)

	return self
end

function IKAngleCalculator:GetRenderAngle(angle)
	local min = self._min

	if math.abs(angle) <= min then
		return angle
	else
		-- BounceRange is the area that the bouncing happens
		-- BounceAmount is the amount of bounce that occurs
		local timesOver = (math.abs(angle) - min) / self._bounceRange
		local scale = (1 - 0.5^timesOver)

		return math.sign(angle) * (min + (scale*self._bounceAmount))
	end
end

function IKAngleCalculator:__index(index)
	if index == "Target" then
		return self._tweener.t
	elseif index == "Angle" then
		return self._tweener.p
	elseif index == "Min" then
		return self._min
	elseif index == "BounceRange" then
		return self._bounceRange
	elseif index == "BounceAmount" then
		return self._bounceAmount
	elseif index == "RenderAngle" then
		return self.Angle
	elseif index == "TimeLeft" then
		return self._tweener.rtime
	elseif IKAngleCalculator[index] then
		return IKAngleCalculator[index]
	else
		error(("[IKAngleCalculator] - '%s' is not a valid member"):format(tostring(index)))
	end
end

function IKAngleCalculator:__newindex(index, Value)
	if index == "Target" then
		self._tweener.t = self:GetRenderAngle(Value)
	elseif index == "Min" then
		rawset(self, "_min", Value)
	elseif index == "BounceRange" then
		rawset(self, "_bounceRange", Value)
	elseif index == "BounceAmount" then
		rawset(self, "_bounceAmount", Value)
	elseif index == "_tweener" then
		rawset(self, index, Value)
	else
		error(("[IKAngleCalculator] - Cannot set '%s', not a valid member"):format(tostring(index)))
	end
end

return IKAngleCalculator

