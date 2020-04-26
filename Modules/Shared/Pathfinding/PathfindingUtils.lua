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
		resolve(path)
	end)
end

function PathfindingUtils.promiseCheckOcclusion(path, startIndex)
	return Promise.spawn(function(resolve, reject)
		resolve(path:CheckOcclusionAsync(startIndex))
	end)

end

function PathfindingUtils.visualizePath(path)
	local maid = Maid.new()

	local parent = Instance.new("Folder")
	parent.Name = "PathVisualization"
	maid:GiveTask(parent)

	for index, waypoint in pairs(path:GetWaypoints()) do
		if waypoint.Action == Enum.PathWaypointAction.Walk then
			local point = Draw.point(waypoint.Position, Color3.new(0.5, 1, 0.5), parent)
			point.Name = ("%03d_WalkPoint"):format(index)
			maid:GiveTask(point)
		elseif waypoint.Action == Enum.PathWaypointAction.Jump then
			local point = Draw.point(waypoint.Position, Color3.new(0.5, 0.5, 1), parent)
			point.Name = ("%03d_JumpPoint"):format(index)
			maid:GiveTask(point)
		end
	end

	parent.Parent = Draw.getDefaultParent()

	return maid
end

return PathfindingUtils