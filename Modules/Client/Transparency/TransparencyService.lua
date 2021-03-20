---
-- @module TransparencyService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Math = require("Math")

local TransparencyService = {}

function TransparencyService:Init()
	assert(not self._properties, "Already initialized")

	self._properties = {
		Transparency = setmetatable({}, {__mode = "k"});
		LocalTransparencyModifier = setmetatable({}, {__mode = "k"})
	}
end

function TransparencyService:SetTransparency(key, part, transparency)
	assert(self._properties, "Not initialized")

	self:_set(key, part, "Transparency", transparency)
end

function TransparencyService:SetLocalTransparencyModifier(key, part, transparency)
	assert(self._properties, "Not initialized")

	self:_set(key, part, "LocalTransparencyModifier", transparency)
end

function TransparencyService:_set(key, part, property, newValue)
	assert(type(key) == "table", "Key must be a table")
	assert(typeof(part) == "Instance", "Part must be instance")

	if newValue == 0 then
		newValue = nil
	end

	local storage = self._properties[property] or error("Not a valid property")

	local partData = storage[part]
	if not partData then
		if not newValue then
			return
		end

		storage[part] = {
			values = {};
			original = part[property];
		}
		partData = storage[part]
	end

	partData.values[key] = newValue

	local valueToSet = nil
	local count = 0
	for _, value in pairs(partData.values) do
		count = count + 1
		if not valueToSet or value > valueToSet then
			valueToSet = value
		end
	end

	if count >= 5 then
		warn(("[TransparencyService] - Part %q has %d transparency instances set to it, memory leak possible")
			:format(part:GetFullName(), count))
	end

	if not valueToSet then
		-- Reset
		storage[part] = nil
		part[property] = partData.original
		return
	end

	part[property] = Math.map(valueToSet, 0, 1, partData.original, 1)
end

function TransparencyService:ResetLocalTransparencyModifier(key, part)
	assert(self._properties, "Not initialized")

	self:SetLocalTransparencyModifier(key, part, nil)
end


function TransparencyService:ResetTransparency(key, part)
	assert(self._properties, "Not initialized")

	self:SetTransparency(key, part, nil)
end

return TransparencyService