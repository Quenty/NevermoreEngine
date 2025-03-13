--[=[
	Service that orchistrates transparency setting from multiple colliding sources
	and handle the transparency appropriately. This means that 2 systems can work with
	transparency without knowing about each other.

	@class TransparencyService
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")

local TransparencyService = {}
TransparencyService.ServiceName = "TransparencyService"

--[=[
	Initializes the transparency service
]=]
function TransparencyService:Init()
	assert(not self._properties, "Already initialized")

	self._properties = {
		Transparency = setmetatable({}, {__mode = "k"});
		LocalTransparencyModifier = setmetatable({}, {__mode = "k"})
	}
end

function TransparencyService:IsDead(): boolean
	return self._properties == nil
end

--[=[
	Uninitializes the transparency service, restoring transparency to original values.
]=]
function TransparencyService:Destroy()
	for propertyName, storage in self._properties do
		for part, data in storage do
			part[propertyName] = data.original
		end
	end

	self._properties = nil
end

--[=[
	Sets the transparency of the part

	@param key any
	@param part Instance
	@param transparency number
]=]
function TransparencyService:SetTransparency(key, part: Instance, transparency: number)
	assert(self._properties, "Not initialized")

	self:_set(key, part, "Transparency", transparency)
end

--[=[
	Sets the local transparency modifier of the part

	@param key any
	@param part Instance
	@param transparency number
]=]
function TransparencyService:SetLocalTransparencyModifier(key, part, transparency)
	assert(self._properties, "Not initialized")

	self:_set(key, part, "LocalTransparencyModifier", transparency)
end

function TransparencyService:_set(key, part: Instance, property, newValue: number?)
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
	for _, value in partData.values do
		count = count + 1
		if not valueToSet or value > valueToSet then
			valueToSet = value
		end
	end

	if count >= 5 then
		warn(string.format("[TransparencyService] - Part %q has %d transparency instances set to it, memory leak possible", part:GetFullName(), count))
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