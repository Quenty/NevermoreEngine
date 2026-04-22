--!strict
--[=[
	Assets in calculating whether the player is idle while moving the camera around or
	aiming a gun.
	@class IdleTargetCalculator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local DIST_BEFORE_MOVEMENT = 0.15
local TIME_UNTIL_IDLE = 1

local IdleTargetCalculator = setmetatable({}, BaseObject)
IdleTargetCalculator.ClassName = "IdleTargetCalculator"
IdleTargetCalculator.__index = IdleTargetCalculator

export type IdleTargetCalculator =
	typeof(setmetatable(
		{} :: {
			_lastTargetPosition: Vector3?,
			_lastMoveTime: number?,
			_disableContextUI: ValueObject.ValueObject<boolean>,
			Changed: Signal.Signal<()>,
		},
		{} :: typeof({ __index = IdleTargetCalculator })
	))
	& BaseObject.BaseObject

function IdleTargetCalculator.new(): IdleTargetCalculator
	local self: IdleTargetCalculator = setmetatable(BaseObject.new() :: any, IdleTargetCalculator)

	self._disableContextUI = self._maid:Add(ValueObject.new(false, "boolean"))

	self.Changed = self._disableContextUI.Changed :: any

	return self
end

function IdleTargetCalculator.GetShouldDisableContextUI(self: IdleTargetCalculator): boolean
	return self._disableContextUI.Value
end

function IdleTargetCalculator.ObserveShouldDisableContextUI(self: IdleTargetCalculator): Observable.Observable<boolean>
	return self._disableContextUI:Observe()
end

function IdleTargetCalculator.SetTarget(self: IdleTargetCalculator, targetPosition: Vector3): ()
	if not targetPosition then
		self._disableContextUI.Value = false
		return
	end

	-- Show UI if no movement for a while
	if self._lastTargetPosition then
		local dist = (self._lastTargetPosition - targetPosition).Magnitude
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
