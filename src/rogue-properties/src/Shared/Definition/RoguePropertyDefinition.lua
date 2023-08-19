--[=[
	@class RoguePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local RogueProperty = require("RogueProperty")
local ServiceBag = require("ServiceBag")
local RoguePropertyUtils = require("RoguePropertyUtils")
local DuckTypeUtils = require("DuckTypeUtils")
local ValueBaseUtils = require("ValueBaseUtils")

local RoguePropertyDefinition = {}
RoguePropertyDefinition.ClassName = "RoguePropertyDefinition"
RoguePropertyDefinition.__index = RoguePropertyDefinition

function RoguePropertyDefinition.new(name, defaultValue, parentPropertyTableDefinition)
	local self = setmetatable({}, RoguePropertyDefinition)

	assert(defaultValue ~= nil, "Bad defaultValue")

	self._name = assert(name, "Bad name")
	self._defaultValue = defaultValue
	self._valueType = typeof(self._defaultValue)
	self._storageType = self:_computeStorageInstanceType()
	self._parentPropertyTableDefinition = parentPropertyTableDefinition or nil
	self._encodedDefaultValue = RoguePropertyUtils.encodeProperty(self, self._defaultValue)

	return self
end

function RoguePropertyDefinition.isRoguePropertyDefinition(value)
	return DuckTypeUtils.isImplementation(RoguePropertyDefinition, value)
end

--[=[
	@param serviceBag ServiceBag
	@param adornee Instance
	@return RogueProperty
]=]
function RoguePropertyDefinition:Get(serviceBag, adornee)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RogueProperty.new(adornee, serviceBag, self)
end

function RoguePropertyDefinition:GetOrCreateInstance(parent)
	assert(typeof(parent) == "Instance", "Bad parent")

	return ValueBaseUtils.getOrCreateValue(
		parent,
		self:GetStorageInstanceType(),
		self:GetName(),
		self:GetEncodedDefaultValue())
end

function RoguePropertyDefinition:GetParentPropertyDefinition()
	return self._parentPropertyTableDefinition
end

--[=[
	Gets the name of the rogue property
	@return string
]=]
function RoguePropertyDefinition:GetName(): string
	return self._name
end

--[=[
	Gets the full name of the rogue property
	@return string
]=]
function RoguePropertyDefinition:GetFullName(): string
	if self._parentPropertyTableDefinition then
		return self._parentPropertyTableDefinition:GetFullName() .. "." .. self._name
	else
		return self._name
	end
end

--[=[
	Gets the default value for the property
	@return TProperty
]=]
function RoguePropertyDefinition:GetDefaultValue()
	return self._defaultValue
end

function RoguePropertyDefinition:GetValueType()
	return self._valueType
end

function RoguePropertyDefinition:GetStorageInstanceType()
	return self._storageType
end

function RoguePropertyDefinition:GetEncodedDefaultValue()
	return rawget(self, "_encodedDefaultValue")
end

function RoguePropertyDefinition:_computeStorageInstanceType()
	if self._valueType == "string" then
		return "StringValue"
	elseif self._valueType == "table" then
		return "Folder"
	elseif self._valueType == "number" then
		return "NumberValue"
	elseif self._valueType == "boolean" then
		return "BoolValue"
	elseif self._valueType == "Color3" then
		return "Color3Value"
	elseif self._valueType == "BrickColor" then
		return "BrickColorValue"
	elseif self._valueType == "Vector3" then
		return "Vector3Value"
	elseif self._valueType == "CFrame" then
		return "CFrameValue"
	else
		error(("Unknown valueType %q"):format(tostring(self._valueType)))
	end
end


return RoguePropertyDefinition