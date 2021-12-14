--- Base object for a cooldown. Provides calculation utilties.
-- @classmod CooldownBase
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TimeSyncService = require("TimeSyncService")

local CooldownBase = setmetatable({}, BaseObject)
CooldownBase.ClassName = "CooldownBase"
CooldownBase.__index = CooldownBase

function CooldownBase.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), CooldownBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._timeSyncService = self._serviceBag:GetService(TimeSyncService)

	self._maid:GivePromise(self._timeSyncService:PromiseSyncedClock())
		:Then(function(syncedClock)
			self._syncedClock = syncedClock
		end)

	return self
end

function CooldownBase:GetTimePassed()
	local startTime = self:GetStartTime()
	if not startTime then
		return nil
	end

	if not self._syncedClock then
		return nil
	end

	return self._syncedClock:GetTime() - startTime
end

function CooldownBase:GetTimeRemaining()
	local endTime = self:GetEndTime()
	if not endTime then
		return nil
	end

	if not self._syncedClock then
		return nil
	end

	return math.max(0, endTime - self._syncedClock:GetTime())
end

function CooldownBase:GetEndTime()
	local startTime = self:GetStartTime()
	if not startTime then
		return nil
	end
	return startTime + self:GetLength()
end

function CooldownBase:GetStartTime()
	error("Not implemented")
end

function CooldownBase:GetLength()
	return self._obj.Value
end

return CooldownBase