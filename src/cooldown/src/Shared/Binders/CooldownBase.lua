--[=[
	Base object for a cooldown. Provides calculation utilties.
	@class CooldownBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TimeSyncService = require("TimeSyncService")
local CooldownConstants = require("CooldownConstants")
local CooldownModel = require("CooldownModel")
local RxAttributeUtils = require("RxAttributeUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local CooldownBase = setmetatable({}, BaseObject)
CooldownBase.ClassName = "CooldownBase"
CooldownBase.__index = CooldownBase

--[=[
	Constructs a new Cooldown.

	@param numberValue NumberValue
	@param serviceBag ServiceBag
	@return CooldownBase
]=]
function CooldownBase.new(numberValue, serviceBag)
	local self = setmetatable(BaseObject.new(numberValue), CooldownBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._timeSyncService = self._serviceBag:GetService(TimeSyncService)

	self._cooldownModel = self._maid:Add(CooldownModel.new())
	self._maid:GivePromise(self._timeSyncService:PromiseSyncedClock())
		:Then(function(syncedClock)
			self._syncedClock = syncedClock

			-- Setup
			self._cooldownModel:SetStartTime(RxAttributeUtils.observeAttribute(self._obj, CooldownConstants.COOLDOWN_START_TIME_ATTRIBUTE, syncedClock:GetTime()))
			self._cooldownModel:SetLength(RxInstanceUtils.observeProperty(self._obj, "Value"))

			self._cooldownModel:SetClock(function()
				return self._syncedClock:GetTime()
			end)
		end)

--[=[
	Event that fires when the cooldown is done.
	@prop Done Signal<()>
	@within CooldownBase
]=]
	self.Done = assert(self._cooldownModel.Done, "No done signal")

	return self
end

function CooldownBase:GetCooldownModel()
	return self._cooldownModel
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
	return self._cooldownModel:GetTimePassed()
end

--[=[
	Gets the time remaining
	@return number?
]=]
function CooldownBase:GetTimeRemaining()
	return self._cooldownModel:GetTimeRemaining()
end

--[=[
	Gets the syncronized time stamp the cooldown is ending at
	@return number?
]=]
function CooldownBase:GetEndTime()
	return self._cooldownModel:GetEndTime()
end

--[=[
	Gets the syncronized time stamp the cooldown is starting at
	@return number?
]=]
function CooldownBase:GetStartTime()
	return self._cooldownModel:GetStartTime()
end

--[=[
	Gets the length of the cooldown
	@return number
]=]
function CooldownBase:GetLength()
	return self._cooldownModel:GetLength()
end

return CooldownBase