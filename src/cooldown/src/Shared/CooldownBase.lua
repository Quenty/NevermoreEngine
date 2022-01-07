--[=[
	Base object for a cooldown. Provides calculation utilties.
	@class CooldownBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TimeSyncService = require("TimeSyncService")
local CooldownConstants = require("CooldownConstants")
local Signal = require("Signal")

local CooldownBase = setmetatable({}, BaseObject)
CooldownBase.ClassName = "CooldownBase"
CooldownBase.__index = CooldownBase

--[=[
	Constructs a new Cooldown.

	@param obj NumberValue
	@param serviceBag ServiceBag
	@return CooldownBase
]=]
function CooldownBase.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), CooldownBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._timeSyncService = self._serviceBag:GetService(TimeSyncService)

	self._maid:GivePromise(self._timeSyncService:PromiseSyncedClock())
		:Then(function(syncedClock)
			self._syncedClock = syncedClock
		end)

--[=[
	Event that fires when the cooldown is done.
	@prop Done Signal<()>
	@within CooldownClient
]=]
	self.Done = Signal.new()
	self._maid:GiveTask(function()
		self.Done:Fire()
		self.Done:Destroy()
	end)

	return self
end

--[=[
	Gets the Roblox instance of the cooldown.
	@return Instance
]=]
function CooldownBase:GetObject()
	return self._obj
end

--[=[
	Gets the time passed
	@return number?
]=]
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

--[=[
	Gets the time remaining
	@return number?
]=]
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

--[=[
	Gets the syncronized time stamp the cooldown is ending at
	@return number?
]=]
function CooldownBase:GetEndTime()
	local startTime = self:GetStartTime()
	if not startTime then
		return nil
	end
	return startTime + self:GetLength()
end

--[=[
	Gets the syncronized time stamp the cooldown is starting at
	@return number?
]=]
function CooldownBase:GetStartTime()
	local startTime = self._obj:GetAttribute(CooldownConstants.COOLDOWN_START_TIME_ATTRIBUTE)
	if type(startTime) == "number" then
		return startTime
	else
		return nil
	end
end

--[=[
	Gets the length of the cooldown
	@return number
]=]
function CooldownBase:GetLength()
	return self._obj.Value
end

return CooldownBase