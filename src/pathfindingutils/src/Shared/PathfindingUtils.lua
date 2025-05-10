--!strict
--[=[
	Utilities involving pathfinding in Roblox
	@class PathfindingUtils
]=]

local require = require(script.Parent.loader).load(script)

local Draw = require("Draw")
local Maid = require("Maid")
local Promise = require("Promise")

local PathfindingUtils = {}

--[=[
	Computes a path wrapped in a promise.

	@param path Path
	@param start Vector3
	@param finish Vector3
	@return Promise<Path>
]=]
function PathfindingUtils.promiseComputeAsync(path: Path, start: Vector3, finish: Vector3): Promise.Promise<Path>
	assert(path, "Bad path")
	assert(start, "Bad start")
	assert(finish, "Bad finish")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			path:ComputeAsync(start, finish)
		end)
		if not ok then
			reject(err or "Failed to compute path")
			return
		end
		return resolve(path)
	end)
end

--[=[
	Checks occlusion wrapped in a promise

	@param path Path
	@param startIndex number
	@return Promise<number>
]=]
function PathfindingUtils.promiseCheckOcclusion(path: Path, startIndex: number): Promise.Promise<number>
	return Promise.spawn(function(resolve, _)
		resolve(path:CheckOcclusionAsync(startIndex))
	end)
end

--[=[
	Visualizes the current waypoints in the path. Will put the visualization in
	Draw libraries default parent.

	@param path Path
	@return MaidTask
]=]
function PathfindingUtils.visualizePath(path: Path): Maid.Maid
	local maid = Maid.new()

	local parent = Instance.new("Folder")
	parent.Name = "PathVisualization"
	maid:GiveTask(parent)

	local lastWaypoint

	for index, waypoint in pairs(path:GetWaypoints()) do
		if waypoint.Action == Enum.PathWaypointAction.Walk then
			local point = maid:Add(Draw.point(waypoint.Position, Color3.new(0.5, 1, 0.5), parent))
			point.Name = string.format("%03d_WalkPoint", index)
		elseif waypoint.Action == Enum.PathWaypointAction.Jump then
			local point = maid:Add(Draw.point(waypoint.Position, Color3.new(0.5, 0.5, 1), parent))
			point.Name = string.format("%03d_JumpPoint", index)
		end

		if lastWaypoint then
			local line = maid:Add(Draw.line(waypoint.Position, lastWaypoint.Position))
			line.Name = string.format("%03d_Line", index)
			line.Parent = parent
		end
		lastWaypoint = waypoint
	end

	parent.Parent = Draw.getDefaultParent()

	return maid
end

return PathfindingUtils
