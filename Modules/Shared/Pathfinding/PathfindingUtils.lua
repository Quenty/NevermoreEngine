---
-- @module PathfindingUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Draw = require("Draw")
local Maid = require("Maid")

local PathfindingUtils = {}

function PathfindingUtils.promiseComputeAsync(path, start, finish)
	assert(path)
	assert(start)
	assert(finish)

	return Promise.spawn(function(resolve, reject)
		path:ComputeAsync(start, finish)

		if path.Status == Enum.PathStatus.Success then
			resolve(path.Status)
		else
			reject(path.Status)
		end
	end)
end

function PathfindingUtils.visualizePath(path)
	local maid = Maid.new()

	for _, waypoint in pairs(path:GetWaypoints()) do
		if waypoint.Action == Enum.PathWaypointAction.Walk then
			maid:GiveTask(Draw.point(waypoint.Position, Color3.new(0.5, 1, 0.5)))
		elseif waypoint.Action == Enum.PathWaypointAction.Jump then
			maid:GiveTask(Draw.point(waypoint.Position, Color3.new(0.5, 0.5, 1)))
		end
	end

	return maid
end

return PathfindingUtils