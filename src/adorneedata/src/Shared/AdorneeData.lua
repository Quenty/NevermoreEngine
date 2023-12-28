--[=[
	Bridges attributes and serializable data table. It's typical to need to define data in 3 ways.

	1. Attributes on an instance for replication
	2. Tables for Lua configuration
	3. Within AttributeValues for writing regular code

	Providing all 3

	@class AdorneeData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeDataEntry = require("AdorneeDataEntry")
local AdorneeDataValue = require("AdorneeDataValue")
local AttributeUtils = require("AttributeUtils")
local t = require("t")

local AdorneeData = {}
AdorneeData.ClassName = "AdorneeData"
AdorneeData.__index = AdorneeData

--[=[
	Attribute data specification

	@param prototype any
	@return AdorneeData<T>
]=]
function AdorneeData.new(prototype)
	local self = setmetatable({}, AdorneeData)

	self._fullPrototype = assert(prototype, "Bad prototype")
	self._attributePrototype = {}
	self._valueObjectPrototype = {}

	for key, item in pairs(self._fullPrototype) do
		if AdorneeDataEntry.isAdorneeDataEntry(item) then
			self._valueObjectPrototype[key] = item
		else
			self._attributePrototype[key] = item
		end
	end

	return self
end

--[=[
	Returns true if the data is valid data, otherwise returns false and an error.

	@param data any
	@return boolean
	@return string -- Error message
]=]
function AdorneeData:IsData(data)
	return self:GetStrictTInterface()(data)
end

--[=[
	Validates and creates a new data table for the data that is readonly and frozen

	@param data T
	@return T
]=]
function AdorneeData:CreateData(data)
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
function AdorneeData:CreatePartialData(partialData)
	assert(self:IsPartialData(partialData))

	return table.freeze(table.clone(partialData))
end


--[=[
	Gets attribute table for the data

	@param adornee Instance
	@return AdorneeDataValue
]=]
function AdorneeData:CreateAdorneeDataValue(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local attributeTableValue = AdorneeDataValue.new(adornee, self._fullPrototype)

	return attributeTableValue
end

--[=[
	Gets the attributes for the adornee

	@param adornee Instance
	@return T
]=]
function AdorneeData:GetAttributes(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local data = {}
	for key, defaultValue in pairs(self._attributePrototype) do
		local result = adornee:GetAttribute(key)
		if result == nil then
			result = defaultValue
		end
		data[key] = result
	end

	-- TODO: Avoid additional allocation
	for key, value in pairs(self._valueObjectPrototype) do
		data[key] = value:CreateValueObject(adornee).Value
	end

	return self:CreateData(data)
end

--[=[
	Sets the attributes for the adornee

	@param adornee Instance
	@param data T
]=]
function AdorneeData:SetAttributes(adornee, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	for key, _ in pairs(self._attributePrototype) do
		adornee:SetAttribute(key, data[key])
	end

	-- TODO: Avoid additional allocation
	for key, value in pairs(self._valueObjectPrototype) do
		value:CreateValueObject(adornee).Value = data[key]
	end
end

--[=[
	Initializes the attributes for the adornee

	@param adornee Instance
	@param data T
]=]
function AdorneeData:InitAttributes(adornee, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	for key, _ in pairs(self._attributePrototype) do
		if adornee:GetAttribute(key) == nil then
			adornee:SetAttribute(key, data[key])
		end
	end

	-- TODO: Avoid additional allocation
	for key, value in pairs(self._valueObjectPrototype) do
		local valueObject = value:CreateValueObject(adornee)
		if valueObject == nil then
			valueObject.Value = data[key]
		end
	end
end

--[=[
	Sets partial attributes on the adornee

	@param adornee Instance
	@param partialData TPartial
]=]
function AdorneeData:SetPartialAttributes(adornee, partialData)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsPartialData(partialData))

	local attributeTable = self:CreateAdorneeDataValue(adornee)
	for key, value in pairs(partialData) do
		attributeTable[key].Value = value
	end
end

--[=[
	Gets a strict interface which will return true if the value is a partial interface and
	false otherwise.

	@return function
]=]
function AdorneeData:GetStrictTInterface()
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
function AdorneeData:GetPartialTInterface()
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

	@param data any
	@return boolean
	@return string -- Error message
]=]
function AdorneeData:IsPartialData(data)
	return self:GetPartialTInterface()(data)
end

function AdorneeData:_getOrCreateTypeInterfaceList()
	if self._typeInterfaceList then
		return self._typeInterfaceList
	end

	local interfaceList = {}

	for key, value in pairs(self._fullPrototype) do
		if AdorneeDataEntry.isAdorneeDataEntry(value) then
			interfaceList[key] = value:GetStrictInterface()
		else
			local valueType = typeof(value)
			assert(AttributeUtils.isValidAttributeType(valueType), "Not a valid value type")

			interfaceList[key] = t.typeof(valueType)
		end
	end

	self._typeInterfaceList = interfaceList
	return interfaceList
end

return AdorneeData