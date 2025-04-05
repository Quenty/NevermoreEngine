--!strict
--[=[
	@class TrajectoryDrawUtils
]=]

local require = require(script.Parent.loader).load(script)

local MinEntranceVelocityUtils = require("MinEntranceVelocityUtils")
local Draw = require("Draw")

local ORIGIN_COLOR = Color3.new(0, 1, 0)
local FINISH_COLOR = Color3.new(1, 0, 0)

local TrajectoryDrawUtils = {}

--[=[
	Draws a trajectory out for debugging purposes
]=]
function TrajectoryDrawUtils.draw(velocity: Vector3, origin: Vector3, target: Vector3, accel: Vector3): ()
	Draw.point(origin, ORIGIN_COLOR)
	Draw.point(target, FINISH_COLOR)

	local entranceTime = MinEntranceVelocityUtils.computeEntranceTime(velocity, origin, target, accel)

	for t = 0, entranceTime, 0.1 do
		local t0 = math.clamp(t, 0, entranceTime)
		local t1 = math.clamp(t + 0.1, 0, entranceTime)

		local p0 = origin + velocity * t0 + 0.5 * accel * t0 * t0
		local p1 = origin + velocity * t1 + 0.5 * accel * t1 * t1

		local percent = t / entranceTime
		Draw.line(p0, p1, ORIGIN_COLOR:Lerp(FINISH_COLOR, percent))
	end
end

return TrajectoryDrawUtils
