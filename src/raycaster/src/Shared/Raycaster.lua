--[=[
	Repeats raycasting attempts while ignoring items via a filter function
	@class Raycaster
]=]

local Workspace = game:GetService("Workspace")

local Raycaster = {}
Raycaster.ClassName = "Raycaster"

--[=[
	Raycast data used by filter functions of the Raycaster.
	@interface RaycastData
	.Part Instance
	.Position Vector3
	.Normal Vector3
	.Material Enum.Material
	@within Raycaster
]=]

--[=[
	Constructs a new Raycaster.
	@param doIgnoreFunction (data: RaycastData) -> boolean -- Returns true to ignore
]=]
function Raycaster.new(doIgnoreFunction)
	local self = setmetatable({
		_ignoreWater = false,
		_maxCasts = 5,
		_ignoreList = {},
	}, Raycaster)

	if doIgnoreFunction then
		self.Filter = doIgnoreFunction
	end

	return self
end

--[=[
	Ignores the value

	@param tableOrInstance Instance | { Instance }
]=]
function Raycaster:Ignore(tableOrInstance)
	if typeof(tableOrInstance) == "Instance" then
		table.insert(self.IgnoreList, tableOrInstance)
		return
	elseif type(tableOrInstance) == "table" then
		local ignoreList = self.IgnoreList
		for _, item in tableOrInstance do
			table.insert(ignoreList, item)
		end
	else
		error(string.format("[Raycaster.Ignore] - Bad arg type %q", type(tableOrInstance)))
	end
end

--[=[
	Repeats raycasts until exhausted attempts, or a result is found.
	@param ray Ray
	@return RaycastData?
]=]
function Raycaster:FindPartOnRay(ray)
	assert(typeof(ray) == "Ray", "Bad ray")

	local ignoreList = table.clone(rawget(self, "_ignoreList"))

	local casts = self.MaxCasts
	while casts > 0 do
		local ok, result = self:_tryCast(ray, ignoreList)
		if ok then
			return result
		end
		casts = casts - 1
	end

	warn(string.format("[Raycaster.FindPartOnRay] - Cast %d times, ran out of casts\n%s", self.MaxCasts, debug.traceback()))
	return nil
end

--[=[
	Current ignore list
	@readonly
	@prop IgnoreList { Instance }
	@within Raycaster
]=]
--[=[
	The current filter function
	@prop Filter function
	@within Raycaster
]=]
--[=[
	Whether or not to ignore water
	@prop IgnoreWater boolean
	@within Raycaster
]=]
--[=[
	Total number of casts allowed
	@prop MaxCasts number
	@within Raycaster
]=]
function Raycaster:__index(index)
	if index == "IgnoreList" then
		return rawget(self, "_ignoreList")
	elseif index == "Filter" then
		return rawget(self, "_filter")
	elseif index == "IgnoreWater" then
		return rawget(self, "_ignoreWater")
	elseif index == "MaxCasts" then
		return rawget(self, "_maxCasts")
	elseif Raycaster[index] then
		return Raycaster[index]
	else
		error(string.format("Unknown index %q", tostring(index)))
	end
end

function Raycaster:__newindex(index, value)
	if index == "IgnoreWater" then
		assert(type(value) == "boolean", "Bad value")
		rawset(self, "_ignoreWater", value)
	elseif index == "MaxCasts" then
		assert(type(value) == "number", "Bad value")
		rawset(self, "_maxCasts", value)
	elseif index == "Filter" then
		assert(type(value) == "function", "Bad value")
		rawset(self, "_filter", value)
	else
		error(string.format("Unknown index %q", tostring(index)))
	end
end

function Raycaster:_tryCast(ray, ignoreList)
	local part, position, normal, material = Workspace:FindPartOnRayWithIgnoreList(
		ray, ignoreList, false, self._ignoreWater)

	if not part then
		return true, nil
	end

	local data = {
		Part = part;
		Position = position;
		Normal = normal;
		Material = material;
	}

	local filter = self.Filter
	if filter and filter(data) then
		table.insert(ignoreList, part)
		return false, nil
	end

	return true, data
end

return Raycaster