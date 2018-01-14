--- Stack-based lighting manager which puts server lighting at the bottom and then
-- allows properties to filter down based upon the stack. Handles lighting effects inside of lighting too.
-- @classmod LightingManagerClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LightingManager = require("LightingManager")
local Table = require("Table")

local LightingManagerClient = setmetatable({}, LightingManager)
LightingManagerClient.__index = LightingManagerClient
LightingManagerClient.ClassName = "LightingManagerClient"

function LightingManagerClient.new()
	local self = setmetatable(LightingManager.new(), LightingManagerClient)

	self._stack = {}

	return self
end

function LightingManagerClient:WithRemoteEvent(remoteEvent)
	assert(not self._remoteEvent)

	self._remoteEvent = remoteEvent or error("No remoteEvent")

	self._remoteEvent.OnClientEvent:Connect(function(propertyTable, time)
		self:AddTween(propertyTable, time, "ServerData")
	end)

	return self
end

-- @param[opt=0] time
-- @param[opt] key
function LightingManagerClient:AddTween(propertyTable, time, key)
	assert(type(propertyTable) == "table", "Property table must be a table")
	time = time or 0
	key = key or HttpService:GenerateGUID(true)

	self:RemoveTween(key, nil, true)

	table.insert(self._stack, {
		Key = key;
		PropertyTable = propertyTable;
	})

	self:_update(time)

	return function()
		self:RemoveTween(key, time)
	end
end

-- @param[opt=0] time
-- @param[opt=false] doNotUpdate
function LightingManagerClient:RemoveTween(key, time, doNotUpdate)
	assert(key, "key is required")
	time = time or 0

	local index = self:GetTweenIndex(key)
	if index then
		table.remove(self._stack, index)

		if not doNotUpdate then
			self:_update(time)
		end

		return true
	end

	return false
end

function LightingManagerClient:_update(time)
	time = time or 0

	local propertyTable = self:_getPropertyTable(self._cachedCurrentTargets)
	local deltaTable, currentValues = self:_getDesiredTweens(propertyTable, self._cachedCurrentTargets)
	self._cachedCurrentTargets = currentValues

	self:_tweenOnItem(Lighting, deltaTable, time)

	if #self._stack >= 4 then
		warn("[LightingManagerClient] - Stack is sized greater than 4, may want to remove!")
	end
end


function LightingManagerClient:_getDesiredTweens(propertyTable, cachedCurrentTargets)
	local function recurse(deltaTable, valueTable, itemToCopy)
		for property, value in pairs(itemToCopy) do
			if type(value) == "table" then
				deltaTable[property] = deltaTable[property] or {}
				valueTable[property] = valueTable[property] or {}

				recurse(deltaTable[property], valueTable[property], value)
			else
				if valueTable[property] ~= value then
					deltaTable[property] = value
					valueTable[property] = value
				end
			end
		end
	end

	local deltaTable = {}
	local currentValues = Table.DeepCopy(cachedCurrentTargets or {})
	recurse(deltaTable, currentValues, propertyTable)

	return deltaTable, currentValues
end

--- Not that fast, that's for sure...
function LightingManagerClient:_getPropertyTable()
	local function recurse(propertyTable, itemToCopy)
		for property, value in pairs(itemToCopy) do
			if type(value) == "table" then
				propertyTable[property] = propertyTable[property] or {}

				assert(type(propertyTable[property]) == "table")

				recurse(propertyTable[property], value)
			else
				if propertyTable[property] == nil then
					--print("Comparing", property, CurrentTargets[property], value)
					propertyTable[property] = value
				end
			end
		end
	end

	local propertyTable = {}

	for i=#self._stack, 1, -1 do
		local data = self._stack[i]
		if data.PropertyTable then
			recurse(propertyTable, data.PropertyTable)
		else
			error("[LightingManagerClient] - Bad item on stack! No property data!")
		end
	end

	return propertyTable
end



function LightingManagerClient:GetTweenIndex(key)
	assert(type(key) == "string")

	for index, item in pairs(self._stack) do
		if item.Key == key then
			return index
		end
	end

	return nil
end

return LightingManagerClient