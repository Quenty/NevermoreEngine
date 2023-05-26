--[=[
	Basic node interacting with the octree. See [Octree](/api/Octree) for usage.

	```lua
	local octree = Octree.new()
	local node = octree:CreateNode(Vector3.zero, "A")
	print(octree:RadiusSearch(Vector3.zero, 100)) --> { "A" }

	node:Destroy() -- Remove node from octree

	print(octree:RadiusSearch(Vector3.zero, 100)) --> { }
	```
	@class OctreeNode
]=]

local require = require(script.Parent.loader).load(script)

local OctreeRegionUtils = require("OctreeRegionUtils")

local OctreeNode = {}
OctreeNode.ClassName = "OctreeNode"
OctreeNode.__index = OctreeNode

--[=[
	Creates a new for the given Octree with the object.

	:::warning
	Use Octree:CreateNode() for more consistent results. To use this object directly
	you need to set the position before it's registered which may be unclean.
	:::

	@private
	@param octree Octree
	@param object T
	@return OctreeNode<T>
]=]
function OctreeNode.new(octree, object)
	local self = setmetatable({}, OctreeNode)

	self._octree = octree or error("No octree")
	self._object = object or error("No object")

	self._currentLowestRegion = nil
	self._position = nil

	return self
end

--[=[
	Finds the nearest neighbors to this node within the radius

	```lua
	local octree = Octree.new()
	local node = octree:CreateNode(Vector3.zero, "A")
	octree:CreateNode(Vector3.new(0, 0, 5), "B")
	print(octree:KNearestNeighborsSearch(10, 100)) --> { "A", "B" } { 0, 25 }
	```

	@param k number -- The number to retrieve
	@param radius number -- The radius to search in
	@return { T } -- Objects found, including self
	@return { number } -- Distances squared
]=]
function OctreeNode:KNearestNeighborsSearch(k, radius)
	return self._octree:KNearestNeighborsSearch(self._position, k, radius)
end

--[=[
	Returns the object stored in the octree

	```lua
	local octree = Octree.new()
	local node = octree:CreateNode(Vector3.zero, "A")
	print(octree:GetObject()) --> "A"
	```

	@return T
]=]
function OctreeNode:GetObject()
	return self._object
end

--[=[
	Finds the nearest neighbors to the octree node

	@param radius number -- The radius to search in
	@return { any } -- Objects found
	@return { number } -- Distances squared
]=]
function OctreeNode:RadiusSearch(radius)
	return self._octree:RadiusSearch(self._position, radius)
end

--[=[
	Retrieves the position

	@return Vector3
]=]
function OctreeNode:GetPosition()
	return self._position
end

--[=[
	Retrieves the as px, py, pz

	@return number -- px
	@return number -- py
	@return number -- pz
]=]
function OctreeNode:GetRawPosition()
	return self._px, self._py, self._pz
end

--[=[
	Sets the position of the octree nodes and updates the octree accordingly

	```lua
	local octree = Octree.new()
	local node = octree:CreateNode(Vector3.zero, "A")
	print(octree:RadiusSearch(Vector3.zero, 100)) --> { "A" }

	node:SetPosition(Vector3.new(1000, 0, 0))
	print(octree:RadiusSearch(Vector3.zero, 100)) --> {}
	```

	@param position Vector3
]=]
function OctreeNode:SetPosition(position)
	if self._position == position then
		return
	end

	local px, py, pz = position.x, position.y, position.z

	self._px = px
	self._py = py
	self._pz = pz
	self._position = position

	if self._currentLowestRegion then
		if OctreeRegionUtils.inRegionBounds(self._currentLowestRegion, px, py, pz) then
			return
		end
	end

	local newLowestRegion = self._octree:GetOrCreateLowestSubRegion(px, py, pz)

	-- Sanity check for debugging
	-- if not OctreeRegionUtils.inRegionBounds(newLowestRegion, px, py, pz) then
	-- 	error("[OctreeNode.SetPosition] newLowestRegion is not in region bounds!")
	-- end

	if self._currentLowestRegion then
		OctreeRegionUtils.moveNode(self._currentLowestRegion, newLowestRegion, self)
	else
		OctreeRegionUtils.addNode(newLowestRegion, self)
	end

	self._currentLowestRegion = newLowestRegion
end

--[=[
	Removes the OctreeNode from the octree
]=]
function OctreeNode:Destroy()
	if self._currentLowestRegion then
		OctreeRegionUtils.removeNode(self._currentLowestRegion, self)
	end
end

return OctreeNode