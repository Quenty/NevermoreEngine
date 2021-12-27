--[=[
	Represents a cooldown state with a time limit
	@class Cooldown
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local TimeSyncService = require("TimeSyncService")
local CooldownConstants = require("CooldownConstants")

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

function Cooldown.new(obj, serviceBag)
	local self = setmetatable(CooldownBase.new(obj, serviceBag), Cooldown)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._startTime = Instance.new("NumberValue")
	self._startTime.Name = CooldownConstants.COOLDOWN_START_TIME_NAME
	self._startTime.Value = self._serviceBag:GetService(TimeSyncService):GetSyncedClock():GetTime()
	self._startTime.Parent = self._obj

	-- Delay for cooldown time
	task.delay(self._obj.Value, function()
		if self.Destroy then
			self._obj:Destroy()
		end
	end)

	return self
end

function Cooldown:GetStartTime()
	return self._startTime.Value
end

return Cooldown