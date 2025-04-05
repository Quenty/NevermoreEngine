--[=[
	@class RoguePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local RogueProperty = require("RogueProperty")
local ServiceBag = require("ServiceBag")
local RoguePropertyUtils = require("RoguePropertyUtils")
local DuckTypeUtils = require("DuckTypeUtils")
local ValueBaseUtils = require("ValueBaseUtils")
local RoguePropertyCacheService = require("RoguePropertyCacheService")

local RoguePropertyDefinition = {}
RoguePropertyDefinition.ClassName = "RoguePropertyDefinition"
RoguePropertyDefinition.__index = RoguePropertyDefinition

function RoguePropertyDefinition.new()
	local self = setmetatable({}, RoguePropertyDefinition)

	self._name = "Unnamed"

	return self
end

function RoguePropertyDefinition:SetDefaultValue(defaultValue)
	assert(defaultValue ~= nil, "Bad defaultValue")

	self._defaultValue = defaultValue
	self._valueType = typeof(self._defaultValue)
	self._storageType = self:_computeStorageInstanceType()
	self._encodedDefaultValue = RoguePropertyUtils.encodeProperty(self, self._defaultValue)
end

function RoguePropertyDefinition.isRoguePropertyDefinition(value: any): boolean
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

	local cacheService = serviceBag:GetService(RoguePropertyCacheService)
	local cache = cacheService:GetCache(self)
	local found = cache:Find(adornee)
	if found then
		return found
	end

	local rogueProperty = RogueProperty.new(adornee, serviceBag, self)
	cache:Store(adornee, rogueProperty)

	return rogueProperty
end

function RoguePropertyDefinition:GetOrCreateInstance(parent)
	assert(typeof(parent) == "Instance", "Bad parent")

	return ValueBaseUtils.getOrCreateValue(
		parent,
		self:GetStorageInstanceType(),
		self:GetName(),
		self:GetEncodedDefaultValue())
end

function RoguePropertyDefinition:SetParentPropertyTableDefinition(parentPropertyTableDefinition)
	self._parentPropertyTableDefinition = parentPropertyTableDefinition
end

function RoguePropertyDefinition:GetParentPropertyDefinition()
	return self._parentPropertyTableDefinition
end

function RoguePropertyDefinition:CanAssign(value, _strict)
	if self._valueType == typeof(value) then
		return true
	else
		return false, string.format("got %q, expected %q when assigning to %q", self._valueType, typeof(value), self:GetFullName())
	end
end

function RoguePropertyDefinition:SetName(name: string)
	assert(type(name) == "string", "Bad name")

	self._name = name
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
		error(string.format("Unknown valueType %q", tostring(self._valueType)))
	end
end


return RoguePropertyDefinition