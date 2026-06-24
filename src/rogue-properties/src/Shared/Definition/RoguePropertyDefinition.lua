--!strict
--[=[
	@class RoguePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local RogueProperty = require("RogueProperty")
local RoguePropertyCacheService = require("RoguePropertyCacheService")
local RoguePropertyConstants = require("RoguePropertyConstants")
local RoguePropertyUtils = require("RoguePropertyUtils")
local ServiceBag = require("ServiceBag")
local ValueBaseUtils = require("ValueBaseUtils")

local RoguePropertyDefinition = {}
RoguePropertyDefinition.ClassName = "RoguePropertyDefinition"
RoguePropertyDefinition.__index = RoguePropertyDefinition

export type RoguePropertyDefinition = typeof(setmetatable(
	{} :: {
		_name: string,
		_defaultValue: any,
		_valueType: string,
		_storageType: string,
		_encodedDefaultValue: any,
		-- Back-reference to the parent RoguePropertyTableDefinition; that class
		-- requires this module (cycle) and is still nonstrict, so it is `any`.
		_parentPropertyTableDefinition: any,
	},
	{} :: typeof({ __index = RoguePropertyDefinition })
))

function RoguePropertyDefinition.new(): RoguePropertyDefinition
	local self: RoguePropertyDefinition = setmetatable({} :: any, RoguePropertyDefinition)

	self._name = "Unnamed"

	return self
end

function RoguePropertyDefinition.SetDefaultValue(self: RoguePropertyDefinition, defaultValue: any)
	assert(defaultValue ~= nil, "Bad defaultValue")

	self._defaultValue = defaultValue
	self._valueType = typeof(self._defaultValue)
	self._storageType = self:_computeStorageInstanceType()
	self._encodedDefaultValue = RoguePropertyUtils.encodeProperty(self :: any, self._defaultValue)
end

function RoguePropertyDefinition.isRoguePropertyDefinition(value: any): boolean
	return DuckTypeUtils.isImplementation(RoguePropertyDefinition, value)
end

function RoguePropertyDefinition.HasChildren(_self: RoguePropertyDefinition): boolean
	return false
end

--[=[
	@param serviceBag ServiceBag
	@param adornee Instance
	@return RogueProperty
]=]
function RoguePropertyDefinition.Get(
	self: RoguePropertyDefinition,
	serviceBag: ServiceBag.ServiceBag,
	adornee: Instance
): RogueProperty.RogueProperty<any>
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	-- Cast: duplicate nested node_modules copies produce a spurious cyclic
	-- "Expected 'RoguePropertyCacheService', got 'RoguePropertyCacheService'".
	local cacheService = serviceBag:GetService(RoguePropertyCacheService) :: any
	local cache = cacheService:GetCache(self)
	local found = cache:Find(adornee)
	if found then
		return found
	end

	local rogueProperty = RogueProperty.new(adornee, serviceBag, self)
	cache:Store(adornee, rogueProperty)

	return rogueProperty
end

function RoguePropertyDefinition.GetOrCreateInstance(self: RoguePropertyDefinition, parent: Instance): Instance
	assert(typeof(parent) == "Instance", "Bad parent")

	-- Note, in forcing the creation, we move to an attribute
	local original = parent:GetAttribute(self:GetName())
	local created = ValueBaseUtils.getOrCreateValue(
		parent,
		self:GetStorageInstanceType() :: any,
		self:GetName(),
		self:GetEncodedDefaultValue()
	)

	if original ~= nil and original ~= RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE then
		(created :: any).Value = original
	end

	parent:SetAttribute(self:GetName(), RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE)
	return created
end

function RoguePropertyDefinition.SetParentPropertyTableDefinition(
	self: RoguePropertyDefinition,
	parentPropertyTableDefinition: any
)
	self._parentPropertyTableDefinition = parentPropertyTableDefinition
end

function RoguePropertyDefinition.GetParentPropertyDefinition(self: RoguePropertyDefinition): any
	return self._parentPropertyTableDefinition
end

function RoguePropertyDefinition.CanAssign(
	self: RoguePropertyDefinition,
	value: any,
	_strict: boolean?
): (boolean, string?)
	if self._valueType == typeof(value) then
		return true
	else
		return false,
			string.format(
				"got %q, expected %q when assigning to %q",
				self._valueType,
				typeof(value),
				self:GetFullName()
			)
	end
end

function RoguePropertyDefinition.SetName(self: RoguePropertyDefinition, name: string): ()
	assert(type(name) == "string", "Bad name")

	self._name = name
end

--[=[
	Gets the name of the rogue property
	@return string
]=]
function RoguePropertyDefinition.GetName(self: RoguePropertyDefinition): string
	return self._name
end

--[=[
	Gets the full name of the rogue property
	@return string
]=]
function RoguePropertyDefinition.GetFullName(self: RoguePropertyDefinition): string
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
function RoguePropertyDefinition.GetDefaultValue(self: RoguePropertyDefinition): any
	return self._defaultValue
end

function RoguePropertyDefinition.GetValueType(self: RoguePropertyDefinition): string
	return self._valueType
end

function RoguePropertyDefinition.GetStorageInstanceType(self: RoguePropertyDefinition): string
	return self._storageType
end

function RoguePropertyDefinition.GetEncodedDefaultValue(self: RoguePropertyDefinition): any
	return rawget(self :: any, "_encodedDefaultValue")
end

function RoguePropertyDefinition._computeStorageInstanceType(self: RoguePropertyDefinition): string
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
