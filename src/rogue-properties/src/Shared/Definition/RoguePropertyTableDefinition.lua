--[=[
	This holds the definition for a variety of tables.
	@class RoguePropertyTableDefinition
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local RoguePropertyArrayUtils = (require :: any)("RoguePropertyArrayUtils")
local RoguePropertyCacheService = require("RoguePropertyCacheService")
local RoguePropertyDefinition = require("RoguePropertyDefinition")
local RoguePropertyDefinitionArrayHelper = require("RoguePropertyDefinitionArrayHelper")
local RoguePropertyService = require("RoguePropertyService")
local RoguePropertyTable = require("RoguePropertyTable")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")
local Set = require("Set")
local _Table = require("Table")

local RoguePropertyTableDefinition = {} -- Inherits from RoguePropertyDefinition
RoguePropertyTableDefinition.ClassName = "RoguePropertyTableDefinition"
RoguePropertyTableDefinition.__index = RoguePropertyTableDefinition

function RoguePropertyTableDefinition.new(tableName: string?, defaultValueTable: _Table.Map<string, any>?)
	local self = setmetatable(RoguePropertyDefinition.new(), RoguePropertyTableDefinition)

	if tableName then
		self:SetName(tableName)
	end

	if defaultValueTable then
		self:SetDefaultValue(defaultValueTable)
	end

	return self
end

function RoguePropertyTableDefinition.isRoguePropertyTableDefinition(value): boolean
	return DuckTypeUtils.isImplementation(RoguePropertyTableDefinition, value)
end

function RoguePropertyTableDefinition:SetDefaultValue(defaultValueTable: _Table.Map<string, any>?)
	assert(type(defaultValueTable) == "table", "Bad defaultValueTable")

	RoguePropertyDefinition.SetDefaultValue(self, defaultValueTable)

	self._definitionMap = {}

	local defaultArrayData = {}

	for key, defaultValue in defaultValueTable do
		if type(key) == "number" then
			table.insert(defaultArrayData, defaultValue)
		else
			if type(defaultValue) == "table" then
				local tableDefinition = RoguePropertyTableDefinition.new()
				tableDefinition:SetName(key)
				tableDefinition:SetParentPropertyTableDefinition(self)
				tableDefinition:SetDefaultValue(defaultValue)

				self._definitionMap[key] = tableDefinition
			else
				local definition = RoguePropertyDefinition.new()
				definition:SetName(key)
				definition:SetParentPropertyTableDefinition(self)
				definition:SetDefaultValue(defaultValue)

				self._definitionMap[key] = definition
			end
		end
	end

	if next(defaultArrayData) ~= nil then
		-- Enforce array data types for sanity
		local requiredPropertyDefinitionTemplate, message =
			RoguePropertyArrayUtils.createRequiredPropertyDefinitionFromArray(defaultArrayData, self)

		if requiredPropertyDefinitionTemplate then
			self._arrayDefinitionHelper =
				RoguePropertyDefinitionArrayHelper.new(self, defaultArrayData, requiredPropertyDefinitionTemplate)
		else
			error(
				string.format(
					"[RoguePropertyTableDefinition] - Could not create infer array type definition. Error: %s",
					message
				)
			)
		end
	end
end

function RoguePropertyTableDefinition:CanAssign(mainValue, strict: boolean): (boolean, string?)
	assert(type(strict) == "boolean", "Bad strict")

	if type(mainValue) ~= "table" then
		return false,
			string.format(
				"got %q, expected %q when assigning to %q",
				self._valueType,
				typeof(mainValue),
				self:GetFullName()
			)
	end

	local remainingKeys: Set.Set<string>
	if strict then
		remainingKeys = Set.fromKeys(self._definitionMap)
	else
		remainingKeys = {}
	end

	for key, value in mainValue do
		remainingKeys[key] = nil

		if type(key) == "number" then
			if self._arrayDefinitionHelper then
				local canAssign, message = self._arrayDefinitionHelper:CanAssignAsArrayMember(value, strict)
				if not canAssign then
					if message then
						return false, message
					else
						return false,
							string.format(
								"Bad index %q of %q due to %s",
								tostring(key),
								self:GetFullName(),
								tostring(message)
							)
					end
				end
			else
				return false, string.format("Bad index %q, %q is not an array", tostring(key), self:GetFullName())
			end
		else
			if self._definitionMap[key] then
				local canAssign, message = self._definitionMap[key]:CanAssign(value, strict)
				if not canAssign then
					if message then
						return false, message
					else
						return false,
							string.format(
								"Bad index %q of %q due to %s",
								tostring(key),
								self:GetFullName(),
								tostring(message)
							)
					end
				end
			else
				return false, string.format("%s.%s is not an expected member", self:GetFullName(), tostring(key))
			end
		end
	end

	-- We missed some keys
	if next(remainingKeys) ~= nil then
		return false,
			string.format(
				"Had %d unassigned keys %q while assigning to %q",
				Set.count(remainingKeys),
				table.concat(Set.toList(remainingKeys), ", "),
				self:GetFullName()
			)
	end

	return true, nil
end

function RoguePropertyTableDefinition:GetDefinitionArrayHelper()
	return self._arrayDefinitionHelper
end

function RoguePropertyTableDefinition:GetDefinitionMap()
	return self._definitionMap
end

--[=[
	Gets the RoguePropertyDefinition if it exists
	@param propertyName
	@return RoguePropertyDefinition?
]=]
function RoguePropertyTableDefinition:GetDefinition(propertyName: string)
	assert(type(propertyName) == "string", "Bad propertyName")

	local definitions = rawget(self, "_definitionMap")
	return definitions[propertyName]
end

--[=[
	Gets a new property table for a given object, which can compute the modified
	value of the adornee. This will initialize the properties on the server.

	@param serviceBag ServiceBag
	@param adornee Instance
	@return RoguePropertyTable
]=]
function RoguePropertyTableDefinition:Get(serviceBag, adornee: Instance)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local cacheService = serviceBag:GetService(RoguePropertyCacheService)
	local cache = cacheService:GetCache(self)
	local found = cache:Find(adornee)
	if found then
		return found
	end

	local roguePropertyTable = RoguePropertyTable.new(adornee, serviceBag, self)
	cache:Store(adornee, roguePropertyTable)

	if not self:GetParentPropertyDefinition() then
		-- Set default value for top level only
		roguePropertyTable:SetCanInitialize(serviceBag:GetService(RoguePropertyService):CanInitializeProperties())
	end

	return roguePropertyTable
end

RoguePropertyTableDefinition.GetPropertyTable = RoguePropertyTableDefinition.Get

--[=[
	Observes the current container while it exists for the given adornee.

	@param adornee Instance
	@param canInitialize boolean
	@return Observable<Brio<Folder>>
]=]
function RoguePropertyTableDefinition:ObserveContainerBrio(adornee: Instance, canInitialize)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	-- TODO: Optimize so we aren't duplcating this logic each time we index a property
	self:GetContainer(adornee, canInitialize)

	local parentDefinition = self:GetParentPropertyDefinition()
	if parentDefinition then
		return parentDefinition:ObserveContainerBrio(adornee, canInitialize):Pipe({
			RxBrioUtils.switchMapBrio(function(parent)
				return RxInstanceUtils.observeLastNamedChildBrio(parent, "Folder", self:GetName())
			end),
		})
	else
		return RxInstanceUtils.observeLastNamedChildBrio(adornee, "Folder", self:GetName())
	end
end

--[=[
	Gets the current container for the given adornee.
	@param adornee Instance
	@param canInitialize boolean
	@return Folder?
]=]
function RoguePropertyTableDefinition:GetContainer(adornee: Instance, canInitialize): Folder?
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	local parent
	local parentDefinition = self:GetParentPropertyDefinition()
	if parentDefinition then
		parent = parentDefinition:GetContainer(adornee, canInitialize)
	else
		parent = adornee
	end

	if not parent then
		return nil
	end

	if canInitialize then
		return self:GetOrCreateInstance(parent)
	else
		return parent:FindFirstChild(self:GetName())
	end
end

function RoguePropertyTableDefinition:GetOrCreateInstance(parent)
	assert(typeof(parent) == "Instance", "Bad parent")

	local existing = parent:FindFirstChild(self:GetName())
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = self:GetName()
	folder.Parent = parent
	return folder
end

function RoguePropertyTableDefinition:__index(index: string)
	assert(type(index) == "string", "Bad index")

	if index == "_definitionMap" or index == "_arrayDefinitionHelper" or index == "_parentPropertyTableDefinition" then
		return rawget(self, index)
	elseif RoguePropertyTableDefinition[index] then
		return RoguePropertyTableDefinition[index]
	elseif RoguePropertyDefinition[index] then
		return RoguePropertyDefinition[index]
	elseif type(index) == "string" then
		local definitions = rawget(self, "_definitionMap")

		if definitions[index] then
			return definitions[index]
		else
			error(string.format("Bad definition %q", tostring(index)))
		end
	elseif type(index) == "number" then
		local definitionArrayHelper = rawget(self, "_arrayDefinitionHelper")
		if definitionArrayHelper then
			local defaultDefinitions = definitionArrayHelper:GetDefaultDefinitions()
			if defaultDefinitions then
				return defaultDefinitions[index]
			else
				-- TODO: Maybe consider returning a generalized property here instead...
				error(string.format("Bad definition %q", tostring(index)))
			end
		else
			error(string.format("Bad definition %q - Not an array", tostring(index)))
		end
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

return RoguePropertyTableDefinition
