--- Repeats raycasting attempts while ignoring items via a filter function
-- @classmod Raycaster

local Workspace = game:GetService("Workspace")

local Raycaster = {}
Raycaster.ClassName = "Raycaster"

function Raycaster.new()
	local self = setmetatable({
		_ignoreWater = false,
		_maxCasts = 5,
		_ignoreList = {},
	}, Raycaster)

	return self
end

function Raycaster:Ignore(value)
	local ignoreList = self.IgnoreList
	if typeof(value) == "Instance" then
		table.insert(ignoreList, value)
		return
	end

	assert(type(value) == "table")
	for _, item in pairs(value) do
		table.insert(ignoreList, item)
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

	warn("Ran out of casts")
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
		error(("Unknown index '%s'"):format(tostring(index)))
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
		error(("Unknown index '%s'"):format(tostring(index)))
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