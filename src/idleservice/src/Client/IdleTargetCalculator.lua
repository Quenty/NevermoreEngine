--[=[
	Assets in calculating whether the player is idle while moving the camera around or
	aiming a gun.
	@class IdleTargetCalculator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")

local DIST_BEFORE_MOVEMENT = 0.15
local TIME_UNTIL_IDLE = 1

local IdleTargetCalculator = setmetatable({}, BaseObject)
IdleTargetCalculator.ClassName = "IdleTargetCalculator"
IdleTargetCalculator.__index = IdleTargetCalculator

function IdleTargetCalculator.new()
	local self = setmetatable(BaseObject.new(), IdleTargetCalculator)

	self._disableContextUI = self._maid:Add(ValueObject.new(false, "boolean"))

	self.Changed = self._disableContextUI.Changed

	return self
end

function IdleTargetCalculator:GetShouldDisableContextUI()
	return self._disableContextUI.Value
end


function IdleTargetCalculator:ObserveShouldDisableContextUI()
	return self._disableContextUI:Observe()
end

function IdleTargetCalculator:SetTarget(targetPosition)
	if not targetPosition then
		self._disableContextUI.Value = false
		return
	end

	-- Show UI if no movement for a while
	if self._lastTargetPosition then
		local dist = (self._lastTargetPosition - targetPosition).magnitude
		if dist >= DIST_BEFORE_MOVEMENT then
			self._lastMoveTime = os.clock()
			self._disableContextUI.Value = true
		else -- not moving
			if not self._lastMoveTime or (os.clock() - self._lastMoveTime) >= TIME_UNTIL_IDLE then
				self._disableContextUI.Value = false
			else
				self._disableContextUI.Value = true
			end
		end
	else
		self._disableContextUI.Value = false
	end

	self._lastTargetPosition = targetPosition
end

return IdleTargetCalculator