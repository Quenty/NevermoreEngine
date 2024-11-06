--[=[
	@class CooldownModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local Signal = require("Signal")
local Rx = require("Rx")
local DuckTypeUtils = require("DuckTypeUtils")

local CooldownModel = setmetatable({}, BaseObject)
CooldownModel.ClassName = "CooldownModel"
CooldownModel.__index = CooldownModel

function CooldownModel.new()
	local self = setmetatable(BaseObject.new(), CooldownModel)

	self._length = self._maid:Add(ValueObject.new(0, "number"))
	self._startTime = self._maid:Add(ValueObject.new(os.clock(), "number"))
	self._clock = self._maid:Add(ValueObject.new(os.clock, "function"))

	do
		self._doneFired = false
		self.Done = Signal.new()

		self._maid:GiveTask(function()
			if not self._doneFired then
				self._doneFired = true
				self.Done:Fire()
			end

			self.Done:Destroy()
		end)
	end

	self._maid:GiveTask(Rx.combineLatestDefer({
		length = self._length:Observe();
		clock = self._clock:Observe();
		startTime = self._startTime:Observe();
	}):Subscribe(function(state)
		local now = state.clock()
		local waitTime = state.length + state.startTime - now

		if self._doneFired then
			self._maid._cleanup = nil
		else
			self._maid._cleanup = task.delay(waitTime, function()
				self._doneFired = true
				self.Done:Fire()
			end)
		end
	end))

	return self
end

function CooldownModel.isCooldownModel(value)
	return DuckTypeUtils.isImplementation(CooldownModel, value)
end

function CooldownModel:SetClock(clock)
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	self._clock:Mount(clock)
end

function CooldownModel:SetStartTime(startTime)
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	self._startTime:Mount(startTime)
end

function CooldownModel:SetLength(length)
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	self._length:Mount(length)
end

--[=[
	Gets the syncronized time stamp the cooldown is starting at
	@return number
]=]
function CooldownModel:GetStartTime()
	return self._startTime.Value
end

--[=[
	Gets the time remaining
	@return number
]=]
function CooldownModel:GetTimeRemaining()
	local endTime = self:GetEndTime()

	return math.max(0, endTime - self._clock.Value())
end

function CooldownModel:GetTimePassed()
	local startTime = self._startTime.Value
	return self._clock.Value() - startTime
end

--[=[
	Gets the syncronized time stamp the cooldown is ending at
	@return number?
]=]
function CooldownModel:GetEndTime()
	return self._startTime.Value + self:GetLength()
end

function CooldownModel:GetLength()
	return self._length.Value
end


return CooldownModel