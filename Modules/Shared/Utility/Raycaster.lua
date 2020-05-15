--- Repeats raycasting attempts while ignoring items via a filter function
-- @classmod Raycaster

local Workspace = game:GetService("Workspace")

local Raycaster = {}
Raycaster.ClassName = "Raycaster"

-- @param doIgnoreFunction(data) Returns true to ignore
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

function Raycaster:Ignore(tableOrInstance)
	if typeof(tableOrInstance) == "Instance" then
		table.insert(self.IgnoreList, tableOrInstance)
		return
	elseif type(tableOrInstance) == "table" then
		local ignoreList = self.IgnoreList
		for _, item in pairs(tableOrInstance) do
			table.insert(ignoreList, item)
		end
	else
		error(("[Raycaster.Ignore] - Bad arg type %q"):format(type(tableOrInstance)))
	end
end

function Raycaster:FindPartOnRay(ray)
	assert(typeof(ray) == "Ray")

	local ignoreList = {}
	for key, value in pairs(rawget(self, "_ignoreList")) do
		ignoreList[key] = value
	end

	local casts = self.MaxCasts
	while casts > 0 do
		local ok, result = self:_tryCast(ray, ignoreList)
		if ok then
			return result
		end
		casts = casts - 1
	end

	warn(("[Raycaster.FindPartOnRay] - Cast %d times, ran out of casts\n%s"):format(self.MaxCasts, debug.traceback()))
	return nil
end

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
		error(("Unknown index %q"):format(tostring(index)))
	end
end

function Raycaster:__newindex(index, value)
	if index == "IgnoreWater" then
		assert(type(value) == "boolean")
		rawset(self, "_ignoreWater", value)
	elseif index == "MaxCasts" then
		assert(type(value) == "number")
		rawset(self, "_maxCasts", value)
	elseif index == "Filter" then
		assert(type(value) == "function")
		rawset(self, "_filter", value)
	else
		error(("Unknown index %q"):format(tostring(index)))
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
