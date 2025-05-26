--!strict
--[=[
	@class CooldownModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DuckTypeUtils = require("DuckTypeUtils")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local CooldownModel = setmetatable({}, BaseObject)
CooldownModel.ClassName = "CooldownModel"
CooldownModel.__index = CooldownModel

export type Clock = () -> number

export type CooldownModel = typeof(setmetatable(
	{} :: {
		_length: ValueObject.ValueObject<number>,
		_startTime: ValueObject.ValueObject<number>,
		_clock: ValueObject.ValueObject<Clock>,
		_doneFired: boolean,
		Done: Signal.Signal<()>,
		_cleanup: any,
	},
	{} :: typeof({ __index = CooldownModel })
)) & BaseObject.BaseObject

--[=[
	Creates a new cooldown model

	@return CooldownModel
]=]
function CooldownModel.new(): CooldownModel
	local self: CooldownModel = setmetatable(BaseObject.new() :: any, CooldownModel)

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
		length = self._length:Observe(),
		clock = self._clock:Observe(),
		startTime = self._startTime:Observe(),
	}):Subscribe(function(state: any)
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

--[=[
	Returns true if the value is a CooldownModel
	@param value any
	@return boolean
]=]
function CooldownModel.isCooldownModel(value: any): boolean
	return DuckTypeUtils.isImplementation(CooldownModel, value)
end

--[=[
	Sets the clock to use for the cooldown
	@param clock Clock
]=]
function CooldownModel.SetClock(self: CooldownModel, clock: ValueObject.Mountable<Clock>): () -> ()
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	return self._clock:Mount(clock)
end

--[=[
	Sets the start time for the cooldown
	@param startTime number
]=]
function CooldownModel.SetStartTime(self: CooldownModel, startTime: ValueObject.Mountable<number>): () -> ()
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	return self._startTime:Mount(startTime)
end

--[=[
	Sets the length of the cooldown
	@param length number
]=]
function CooldownModel.SetLength(self: CooldownModel, length: ValueObject.Mountable<number>): () -> ()
	if self._doneFired then
		warn("[CooldownModel] - Done already fired")
	end

	return self._length:Mount(length)
end

--[=[
	Gets the syncronized time stamp the cooldown is starting at
	@return number
]=]
function CooldownModel.GetStartTime(self: CooldownModel): number
	return self._startTime.Value
end

--[=[
	Gets the time remaining
	@return number
]=]
function CooldownModel.GetTimeRemaining(self: CooldownModel): number
	local endTime = self:GetEndTime()

	return math.max(0, endTime - self._clock.Value())
end

--[=[
	Gets the time passed
	@return number
]=]
function CooldownModel.GetTimePassed(self: CooldownModel): number
	local startTime = self._startTime.Value
	return self._clock.Value() - startTime
end

--[=[
	Gets the syncronized time stamp the cooldown is ending at
	@return number?
]=]
function CooldownModel.GetEndTime(self: CooldownModel)
	return self._startTime.Value + self:GetLength()
end

--[=[
	Gets the length of the cooldown
	@return number
]=]
function CooldownModel.GetLength(self: CooldownModel): number
	return self._length.Value
end

return CooldownModel
