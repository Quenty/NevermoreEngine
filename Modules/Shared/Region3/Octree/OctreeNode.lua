--- Basic node interacting with the octree
-- @classmod OctreeNode
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local OctreeRegionUtils = require("OctreeRegionUtils")

local OctreeNode = {}
OctreeNode.ClassName = "OctreeNode"
OctreeNode.__index = OctreeNode

function OctreeNode.new(octree, object)
	return setmetatable({
		_octree = octree or error("No octree"),
		_object = object or error("No object"),

		_currentLowestRegion = nil,
		_position = nil
	}, OctreeNode)
end

function OctreeNode:KNearestNeighborsSearch(k, radius)
	return self._octree:KNearestNeighborsSearch(self._position, k, radius)
end

function OctreeNode:GetObject()
	return self._object
end

function OctreeNode:RadiusSearch(radius)
	return self._octree:RadiusSearch(self._position, radius)
end

function OctreeNode:GetPosition()
	return self._position
end

function OctreeNode:GetRawPosition()
	return self._px, self._py, self._pz
end

function OctreeNode:SetPosition(position)
	if self._position == position then
		return
	end

	local px = position.x
	local py = position.y
	local pz = position.z

	self._px = px
	self._py = py
	self._pz = pz
	self._position = position

	local currentLowestRegion = self._currentLowestRegion
	if currentLowestRegion then
		if OctreeRegionUtils.inRegionBounds(currentLowestRegion, px, py, pz) then
			return
		end
	end

	local newLowestRegion = self._octree:GetOrCreateLowestSubRegion(px, py, pz)

	-- Sanity check for debugging
	-- if not OctreeRegionUtils.inRegionBounds(newLowestRegion, px, py, pz) then
	-- 	error("[OctreeNode.SetPosition] newLowestRegion is not in region bounds!")
	-- end

	if currentLowestRegion then
		OctreeRegionUtils.moveNode(currentLowestRegion, newLowestRegion, self)
	else
		OctreeRegionUtils.addNode(newLowestRegion, self)
	end
	self._currentLowestRegion = newLowestRegion
end

function OctreeNode:Destroy()
	local currentLowestRegion = self._currentLowestRegion
	if currentLowestRegion then
		OctreeRegionUtils.removeNode(currentLowestRegion, self)
	end
end

return OctreeNode