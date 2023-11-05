--[=[
	Bridges attributes and serializable data table. It's typical to need to define data in 3 ways.

	1. Attributes on an instance for replication
	2. Tables for Lua configuration
	3. Within AttributeValues for writing regular code

	Providing all 3

	@class AttributeData
]=]

local require = require(script.Parent.loader).load(script)

local AttributeTableValue = require("AttributeTableValue")
local t = require("t")
local AttributeUtils = require("AttributeUtils")

local AttributeData = {}
AttributeData.ClassName = "AttributeData"
AttributeData.__index = AttributeData

--[=[
	Attribute data specification

	@return AttributeData<T>
]=]
function AttributeData.new(prototype)
	local self = setmetatable({}, AttributeData)

	self._prototype = assert(prototype, "Bad prototype")

	return self
end

--[=[
	Returns true if the data is valid data, otherwise returns false and an error.

	@return boolean
	@return string -- Error message
]=]
function AttributeData:IsData(data)
	return self:GetStrictTInterface()(data)
end

--[=[
	Validates and creates a new data table for the data that is readonly and frozen

	@param data T
	@return T
]=]
function AttributeData:CreateData(data)
	assert(self:IsData(data))

	return table.freeze(table.clone(data))
end


--[=[
	Validates and creates a new data table that is readonly and frozen, but for partial
	data.

	The partial data can just be part of the attributes.

	@param partialData TPartial
	@return TPartial
]=]
function AttributeData:CreatePartialData(partialData)
	assert(self:IsPartialData(partialData))

	return table.freeze(table.clone(partialData))
end


--[=[
	Gets attribute table for the data

	@param adornee Instance
	@return AttributeTableValue
]=]
function AttributeData:CreateAttributeTableValue(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return AttributeTableValue.new(adornee, self._prototype)
end

--[=[
	Gets the attributes for the adornee

	@param adornee Instance
	@return T
]=]
function AttributeData:GetAttributes(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local data = {}
	for key, value in pairs(self._prototype) do
		data[key] = adornee:GetAttribute(value)
	end
	return self:CreateData(data)
end

--[=[
	Sets the attributes for the adornee

	@param adornee Instance
	@param data T
]=]
function AttributeData:SetAttributes(adornee, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	for key, value in pairs(data) do
		adornee:SetAttribute(key, value)
	end
end

--[=[
	Initializes the attributes for the adornee
]=]
function AttributeData:InitAttributes(adornee, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	for key, value in pairs(data) do
		if adornee:GetAttribute(key) == nil then
			adornee:SetAttribute(key, value)
		end
	end
end

--[=[
	@param partialData TPartial
]=]
function AttributeData:SetPartialAttributes(adornee, partialData)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsPartialData(partialData))

	local attributeTable = self:CreateAttributeTableValue(adornee)
	for key, value in pairs(partialData) do
		attributeTable[key].Value = value
	end
end

--[=[
	Gets a strict interface which will return true if the value is a partial interface and
	false otherwise.

	@return function
]=]
function AttributeData:GetStrictTInterface()
	if self._fullInterface then
		return self._fullInterface
	end

	self._fullInterface = t.strictInterface(self:_getOrCreateTypeInterfaceList())
	return self._fullInterface
end

--[=[
	Gets a [t] interface which will return true if the value is a partial interface, and
	false otherwise.

	@return function
]=]
function AttributeData:GetPartialTInterface()
	if self._partialInterface then
		return self._partialInterface
	end

	local interfaceList = {}
	for key, value in pairs(self:_getOrCreateTypeInterfaceList()) do
		interfaceList[key] = t.optional(value)
	end

	self._partialInterface = t.strictInterface(interfaceList)
	return self._partialInterface
end


--[=[
	Returns true if the data is valid partial data, otherwise returns false and an error.

	@return boolean
	@return string -- Error message
]=]
function AttributeData:IsPartialData(data)
	return self:GetPartialTInterface()(data)
end

function AttributeData:_getOrCreateTypeInterfaceList()
	if self._typeInterfaceList then
		return self._typeInterfaceList
	end

	local interfaceList = {}

	for key, value in pairs(self._prototype) do
		local valueType = typeof(value)
		assert(AttributeUtils.isValidAttributeType(valueType), "Not a valid value type")

		interfaceList[key] = t.typeof(valueType)
	end

	self._typeInterfaceList = interfaceList
	return interfaceList
end

return AttributeData