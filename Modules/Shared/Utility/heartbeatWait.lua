--- Heartbeat wait for short waits to avoid wait queue being weird
-- @module heartbeatWait

local RunService = game:GetService("RunService")

local heartbeat = RunService.Heartbeat

return function(waitTime)
	assert(type(waitTime) == "number")
	assert(waitTime > 0)

	local startTime = tick()
	while (tick() - startTime) < waitTime do
		heartbeat:Wait()
	end

	return tick() - startTime
end