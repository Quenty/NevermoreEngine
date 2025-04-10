--!strict
--[=[
	@class FunnelStepTracker
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local BaseObject = require("BaseObject")
local _Maid = require("Maid")

local FunnelStepTracker = setmetatable({}, BaseObject)
FunnelStepTracker.ClassName = "FunnelStepTracker"
FunnelStepTracker.__index = FunnelStepTracker

export type FunnelStepTracker = typeof(setmetatable(
	{} :: {
		_stepsLogged: { [number]: string },
		StepLogged: Signal.Signal<number, string>,
	},
	{} :: typeof({ __index = FunnelStepTracker })
)) & BaseObject.BaseObject

--[=[
	Constructs a new FunnelStepTracker

	@return FunnelStepTracker
]=]
function FunnelStepTracker.new(): FunnelStepTracker
	local self: FunnelStepTracker = setmetatable(BaseObject.new() :: any, FunnelStepTracker)

	self._stepsLogged = {}

	self.StepLogged = self._maid:Add(Signal.new() :: any)

	return self
end

--[=[
	Logs a step
]=]
function FunnelStepTracker.LogStep(self: FunnelStepTracker, stepNumber: number, stepName: string): ()
	assert(type(stepNumber) == "number", "Bad stepNumber")
	assert(type(stepName) == "string", "Bad stepName")

	if self._stepsLogged[stepNumber] then
		if self._stepsLogged[stepNumber] ~= stepName then
			error(
				string.format(
					"[FunnelStepTracker.LogStep] - Trying to log step with 2 separate names, %q and %d",
					self._stepsLogged[stepNumber],
					stepNumber
				)
			)
		end

		return
	end

	self._stepsLogged[stepNumber] = stepName

	self.StepLogged:Fire(stepNumber, stepName)
end

--[=[
	Returns true if the step is complete

	@param stepNumber number
	@return string?
]=]
function FunnelStepTracker.IsStepComplete(self: FunnelStepTracker, stepNumber: number): boolean
	assert(type(stepNumber) == "number", "Bad stepNumber")

	return self._stepsLogged[stepNumber] ~= nil
end

--[=[
	Gets the logged steps

	@return { [number]: string }
]=]
function FunnelStepTracker.GetLoggedSteps(self: FunnelStepTracker): { [number]: string }
	return table.clone(self._stepsLogged)
end

--[=[
	Clears all logged steps
]=]
function FunnelStepTracker.ClearLoggedSteps(self: FunnelStepTracker)
	table.clear(self._stepsLogged)
end

return FunnelStepTracker