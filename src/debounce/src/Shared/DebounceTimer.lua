--!strict
--[=[
	DebounceTimer
	@class DebounceTimer
]=]

local DebounceTimer = {}
DebounceTimer.ClassName = "DebounceTimer"
DebounceTimer.__index = DebounceTimer

export type DebounceTimer = typeof(setmetatable(
	{} :: {
		_length: number,
		_startTime: number?,
	},
	{} :: typeof({ __index = DebounceTimer })
))

--[=[
	@param length number
	@return DebounceTimer
]=]
function DebounceTimer.new(length: number): DebounceTimer
	local self: DebounceTimer = setmetatable({} :: any, DebounceTimer)

	self._length = length or error("No length")

	return self
end

--[=[
	Gets the length
	@param length number
]=]
function DebounceTimer.SetLength(self: DebounceTimer, length: number)
	self._length = length or error("No length")
end

--[=[
	Restarts the timer
]=]
function DebounceTimer.Restart(self: DebounceTimer)
	self._startTime = os.clock()
end

--[=[
	Returns whether or not the timer is running.
	@return boolean
]=]
function DebounceTimer.IsRunning(self: DebounceTimer): boolean
	return self._startTime ~= nil
end

--[=[
	Returns the amount of time remaining in the timer.
	@return number
]=]
function DebounceTimer.GetTimeRemaining(self: DebounceTimer): number
	if not self:IsRunning() then
		return 0
	end

	assert(self._startTime, "No start time")
	return math.max((self._startTime + self._length) - os.clock(), 0)
end

--[=[
	Returns if the timer is done
	@return boolean
]=]
function DebounceTimer.IsDone(self: DebounceTimer): boolean
	if not self:IsRunning() then
		return true
	end

	assert(self._startTime, "No start time")
	return (os.clock() - self._startTime) >= self._length
end

return DebounceTimer
