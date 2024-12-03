--[=[
	Server-side funnel logger

	@class FunnelStepLogger
]=]

local require = require(script.Parent.loader).load(script)

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local FunnelStepTracker = require("FunnelStepTracker")

local FunnelStepLogger = setmetatable({}, BaseObject)
FunnelStepLogger.ClassName = "FunnelStepLogger"
FunnelStepLogger.__index = FunnelStepLogger

function FunnelStepLogger.new(player, funnelName)
	local self = setmetatable(BaseObject.new(), FunnelStepLogger)

	self._player = assert(player, "No player")
	self._stepTracker = self._maid:Add(FunnelStepTracker.new())
	self._funnelName = assert(funnelName, "Bad funnelName")
	self._funnelSessionId = HttpService:GenerateGUID(false)
	self._printDebugEnabled = false

	local steps = self._stepTracker:GetLoggedSteps()
	if next(steps) then
		-- Give us time to print if we need
		self._maid:GiveTask(task.defer(function()
			for stepNumber, stepName in pairs(steps) do
				self:_sendStep(stepNumber, stepName)
			end
		end))
	end

	self._maid:GiveTask(self._stepTracker.StepLogged:Connect(function(stepNumber, stepName)
		self:_sendStep(stepNumber, stepName)
	end))

	return self
end

function FunnelStepLogger:SetPrintDebugEnabled(debugEnabled)
	assert(type(debugEnabled) == "boolean", "Bad debugEnabled")

	self._printDebugEnabled = debugEnabled
end

function FunnelStepLogger:LogStep(stepNumber, stepName)
	assert(type(stepNumber) == "number", "Bad stepNumber")
	assert(type(stepName) == "string", "Bad stepName")

	self._stepTracker:LogStep(stepNumber, stepName)
end

function FunnelStepLogger:_sendStep(stepNumber, stepName)
	AnalyticsService:LogFunnelStepEvent(self._player, self._funnelName, self._funnelSessionId, stepNumber, stepName)

	if self._printDebugEnabled then
		print(string.format("%s - %d - %s", self._funnelName, stepNumber, stepName))
	end
end

return FunnelStepLogger