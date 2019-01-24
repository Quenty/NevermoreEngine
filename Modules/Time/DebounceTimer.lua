--- DebounceTimer
-- @classmod DebounceTimer

local DebounceTimer = {}
DebounceTimer.ClassName = "DebounceTimer"
DebounceTimer.__index = DebounceTimer

function DebounceTimer.new(length)
	local self = setmetatable({}, DebounceTimer)

	self._length = length or error("No length")

	return self
end

function DebounceTimer:SetLength(length)
	self._length = length or error("No length")
end

function DebounceTimer:Restart()
	self._startTime = tick()
end

function DebounceTimer:IsRunning()
	return self._startTime ~= nil
end

function DebounceTimer:IsDone()
	if not self:IsRunning() then
		return true
	end

	return (tick() - self._startTime) >= self._length
end

return DebounceTimer