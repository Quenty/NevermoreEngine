--!strict
--[=[
	Utility functions for addressing instances by a dotted path, like `"Master.Music"`,
	relative to some root instance.

	@class InstancePathUtils
]=]

local InstancePathUtils = {}

--[=[
	A dotted path naming each instance to descend through, like `"Master.Music"`.

	@type InstancePath string
	@within InstancePathUtils
]=]
export type InstancePath = string

--[=[
	An instance path split into its individual instance names.

	@type InstancePathTable { string }
	@within InstancePathUtils
]=]
export type InstancePathTable = { string }

--[=[
	Either form of an instance path, so a caller can pass whichever it already holds.

	@type InstancePathTableLike InstancePath | InstancePathTable
	@within InstancePathUtils
]=]
export type InstancePathTableLike = InstancePath | InstancePathTable

--[=[
	Checks if the given value is a valid instance path.

	@param instancePath any
	@return boolean
]=]
function InstancePathUtils.isInstancePath(instancePath: any): boolean
	return type(instancePath) == "string"
end

--[=[
	Checks if the given value is either form of an instance path.

	@param instancePath any
	@return boolean
]=]
function InstancePathUtils.isInstancePathTableLike(instancePath: any): boolean
	return type(instancePath) == "string" or type(instancePath) == "table"
end

--[=[
	Converts an instance path into a table of instance names. A path table is copied, so callers
	that go on to mutate the result cannot reach back into what they were given.

	@param instancePath InstancePathTableLike
	@return InstancePathTable
]=]
function InstancePathUtils.toPathTable(instancePath: InstancePathTableLike): InstancePathTable
	if type(instancePath) == "table" then
		return table.clone(instancePath)
	end

	assert(type(instancePath) == "string", "Bad instancePath")

	return string.split(instancePath, ".")
end

--[=[
	Converts a table of instance names into an instance path.

	@param pathTable InstancePathTableLike
	@return InstancePath
]=]
function InstancePathUtils.fromPathTable(pathTable: InstancePathTableLike): InstancePath
	if type(pathTable) == "string" then
		return pathTable
	end

	assert(type(pathTable) == "table", "Bad pathTable")

	return table.concat(pathTable, ".")
end

--[=[
	Returns the path to the parent of the given path, that is, every name except the last
	one. Returns nil if the path names a direct child of the root, and so has no parent
	path.

	```lua
	InstancePathUtils.getParentPath("Quenty.default") --> "Quenty"
	InstancePathUtils.getParentPath("default") --> nil
	```

	@param instancePath InstancePath
	@return InstancePath?
]=]
function InstancePathUtils.getParentPath(instancePath: InstancePath): InstancePath?
	local pathTable = InstancePathUtils.toPathTable(instancePath)
	if #pathTable <= 1 then
		return nil
	end

	table.remove(pathTable)

	return InstancePathUtils.fromPathTable(pathTable)
end

--[=[
	Returns the name of the instance the path points at, that is, the last name in the path.

	```lua
	InstancePathUtils.getName("Quenty.default") --> "default"
	```

	@param instancePath InstancePath
	@return string
]=]
function InstancePathUtils.getName(instancePath: InstancePath): string
	local pathTable = InstancePathUtils.toPathTable(instancePath)

	return pathTable[#pathTable]
end

--[=[
	Finds the instance at the given path underneath the root. Each name in the path must
	resolve to a child of the given class name, if one is given.

	@param root Instance
	@param instancePath InstancePath
	@param className string?
	@return Instance?
]=]
function InstancePathUtils.findInstance(root: Instance, instancePath: InstancePath, className: string?): Instance?
	assert(typeof(root) == "Instance", "Bad root")
	assert(type(instancePath) == "string", "Bad instancePath")
	assert(type(className) == "string" or className == nil, "Bad className")

	local current: Instance = root
	for _, name in InstancePathUtils.toPathTable(instancePath) do
		local found = InstancePathUtils._findChild(current, name, className)
		if not found then
			return nil
		end
		current = found
	end

	return current
end

--[=[
	Finds the instance at the given path underneath the root, constructing any missing
	instances along the way. Each newly constructed instance is passed to `onCreate`
	before it is parented, if a callback is given.

	@param root Instance
	@param instancePath InstancePath
	@param className string
	@param onCreate ((instance: Instance) -> ())?
	@return Instance
]=]
function InstancePathUtils.findOrCreateInstance(
	root: Instance,
	instancePath: InstancePath,
	className: string,
	onCreate: ((instance: Instance) -> ())?
): Instance
	assert(typeof(root) == "Instance", "Bad root")
	assert(type(instancePath) == "string", "Bad instancePath")
	assert(type(className) == "string", "Bad className")
	assert(type(onCreate) == "function" or onCreate == nil, "Bad onCreate")

	local current: Instance = root
	for _, name in InstancePathUtils.toPathTable(instancePath) do
		local parent = current
		local found = InstancePathUtils._findChild(parent, name, className)

		if found then
			current = found
		else
			local constructed = Instance.new(className :: any)
			constructed.Name = name

			if onCreate then
				onCreate(constructed)
			end

			constructed.Parent = parent
			current = constructed
		end
	end

	return current
end

--[=[
	Returns the path of the given instance relative to the root, which lets a path be derived
	from the tree instead of being stored alongside it. Returns nil if the instance is not a
	descendant of the root.

	Note that instance names containing a `"."` cannot be addressed by a path, so the result
	will not round-trip through [InstancePathUtils.findInstance] in that case.

	@param root Instance
	@param instance Instance
	@return InstancePath?
]=]
function InstancePathUtils.getPathTo(root: Instance, instance: Instance): InstancePath?
	assert(typeof(root) == "Instance", "Bad root")
	assert(typeof(instance) == "Instance", "Bad instance")

	if instance == root then
		return nil
	end

	local pathTable = {}
	local current: Instance? = instance

	while current and current ~= root do
		table.insert(pathTable, 1, current.Name)
		current = current.Parent
	end

	if current ~= root then
		return nil
	end

	return InstancePathUtils.fromPathTable(pathTable)
end

function InstancePathUtils._findChild(parent: Instance, name: string, className: string?): Instance?
	if className == nil then
		return parent:FindFirstChild(name)
	end

	for _, item in parent:GetChildren() do
		if item.Name == name and item:IsA(className) then
			return item
		end
	end

	return nil
end

return InstancePathUtils
