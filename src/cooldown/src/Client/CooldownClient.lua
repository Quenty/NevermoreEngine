--[=[
	Handles cooldown on the client
	@class CooldownClient
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local CooldownConstants = require("CooldownConstants")
local promiseChild = require("promiseChild")
local Signal = require("Signal")

local CooldownClient = setmetatable({}, CooldownBase)
CooldownClient.ClassName = "CooldownClient"
CooldownClient.__index = CooldownClient

function CooldownClient.new(obj, serviceBag)
	local self = setmetatable(CooldownBase.new(obj, serviceBag), CooldownClient)

	self.Done = Signal.new()
	self._maid:GiveTask(function()
		self.Done:Fire()
		self.Done:Destroy()
	end)

	return self
end

function CooldownClient:GetStartTime()
	local promise = self:PromiseStartTimeValue()
	if promise:IsFulfilled() then
		return promise:Wait().Value
	else
		return nil
	end
end

function CooldownClient:PromiseStartTimeValue()
	if self._startTimePromise then
		return self._startTimePromise
	end

	self._startTimePromise = promiseChild(self._obj, CooldownConstants.COOLDOWN_START_TIME_NAME)
	self._maid:GiveTask(self._startTimePromise)

	return self._startTimePromise
end

return CooldownClient