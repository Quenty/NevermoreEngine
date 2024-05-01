--[=[
	DebounceTimer
	@class DebounceTimer
]=]

local DebounceTimer = {}
DebounceTimer.ClassName = "DebounceTimer"
DebounceTimer.__index = DebounceTimer

--[=[
	@param length number
	@return DebounceTimer
]=]
function DebounceTimer.new(length)
	local self = setmetatable({}, DebounceTimer)

	self._length = length or error("No length")

	return self
end

--[=[
	Gets the length
	@param length number
]=]
function DebounceTimer:SetLength(length)
	self._length = length or error("No length")
end


--[=[
	Restarts the timer
]=]
function DebounceTimer:Restart()
	self._startTime = tick()
end

--[=[
	Returns whether or not the timer is running.
	@return boolean
]=]
function DebounceTimer:IsRunning()
	return self._startTime ~= nil
end

--[=[
	Returns the amount of time remaining in the timer.
	@return number
]=]
function DebounceTimer:GetTimeRemaining()
	if not self:IsRunning() then
		return 0
	end

	return math.min((self._startTime + self._length) - tick(), 0)
end

--[=[
	Returns if the timer is done
	@return boolean
]=]
function DebounceTimer:IsDone()
	if not self:IsRunning() then
		return true
	end

	return (tick() - self._startTime) >= self._length
end

return DebounceTimer