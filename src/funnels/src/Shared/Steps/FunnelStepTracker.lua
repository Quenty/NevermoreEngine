--[=[
	@class FunnelStepTracker
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local BaseObject = require("BaseObject")

local FunnelStepTracker = setmetatable({}, BaseObject)
FunnelStepTracker.ClassName = "FunnelStepTracker"
FunnelStepTracker.__index = FunnelStepTracker

function FunnelStepTracker.new()
	local self = setmetatable(BaseObject.new(), FunnelStepTracker)

	self._stepsLogged = {}

	self.StepLogged = self._maid:Add(Signal.new())

	return self
end

function FunnelStepTracker:LogStep(stepNumber, stepName)
	assert(type(stepNumber) == "number", "Bad stepNumber")
	assert(type(stepName) == "string", "Bad stepName")

	if self._stepsLogged[stepNumber] then
		if self._stepsLogged[stepNumber] ~= stepName then
			error(string.format("[FunnelStepTracker.LogStep] - Trying to log step with 2 separate names, %q and %q", self._stepsLogged[stepNumber], stepNumber))
		end

		return
	end

	self._stepsLogged[stepNumber] = stepName

	self.StepLogged:Fire(stepNumber, stepName)
end

function FunnelStepTracker:IsStepComplete(stepNumber)
	assert(type(stepNumber) == "number", "Bad stepNumber")

	return self._stepsLogged[stepNumber] ~= nil
end

function FunnelStepTracker:GetLoggedSteps()
	return table.clone(self._stepsLogged)
end

function FunnelStepTracker:ClearLoggedSteps()
	table.clear(self._stepsLogged)
end

return FunnelStepTracker