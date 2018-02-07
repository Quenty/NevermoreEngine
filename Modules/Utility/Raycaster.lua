--- Repeats raycasting attempts while ignoring items via a filter function
-- @classmod Raycaster

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

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

	local casts = self.MaxCasts
	while casts > 0 do
		local result = self:_tryCast(ray)
		if result then
			return result
		end
		casts = casts - 1
	end
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

function Raycaster:_tryCast(ray)
	local ignoreList = Table.Copy(self.IgnoreList)
	local part, position, normal, material = workspace:FindPartOnRayWithIgnoreList(
		ray, ignoreList, false, self._ignoreWater)

	if not part then
		return nil
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
		return nil
	end

	return data
end

return Raycaster