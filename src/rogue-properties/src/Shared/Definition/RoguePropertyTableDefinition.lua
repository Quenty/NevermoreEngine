--[=[
	This holds the definition for a variety of tables.
	@class RoguePropertyTableDefinition
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyTable = require("RoguePropertyTable")
local ServiceBag = require("ServiceBag")
local RoguePropertyDefinition = require("RoguePropertyDefinition")
local RxInstanceUtils = require("RxInstanceUtils")
local RoguePropertyService = require("RoguePropertyService")

local RoguePropertyTableDefinition = {}
RoguePropertyTableDefinition.ClassName = "RoguePropertyTableDefinition"
RoguePropertyTableDefinition.__index = RoguePropertyTableDefinition

function RoguePropertyTableDefinition.new(tableName: string, propertyDefinition: {[string]: any})
	local self = setmetatable({}, RoguePropertyTableDefinition)

	assert(type(tableName) == "string", "Bad tableName")
	assert(type(propertyDefinition) == "table", "Bad propertyDefinition")

	self._tableName = tableName
	self._definitionMap = {}

	for key, defaultValue in pairs(propertyDefinition) do
		self._definitionMap[key] = RoguePropertyDefinition.new(key, defaultValue, self)
	end

	return self
end

--[=[
	Gets the name of the rogue property table
	@return string
]=]
function RoguePropertyTableDefinition:GetName(): string
	return self._tableName
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
function RoguePropertyTableDefinition:GetPropertyTable(serviceBag, adornee)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RoguePropertyTable.new(adornee, serviceBag, self)
end

--[=[
	Observes the current container while it exists for the given adornee.

	@param serviceBag ServiceBag
	@param adornee Instance
	@return Observable<Brio<Folder>>
]=]
function RoguePropertyTableDefinition:ObserveContainerBrio(serviceBag, adornee)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	-- TODO: Optimize so we aren't duplcating this logic each time we index a property
	if serviceBag:GetService(RoguePropertyService):CanInitializeProperties() then
		self:_ensureContainer(adornee)
	end

	return RxInstanceUtils.observeLastNamedChildBrio(adornee, "Folder", self._tableName)
end

--[=[
	Gets the current container for the given adornee.
	@param serviceBag ServiceBag
	@param adornee Instance
	@return Folder?
]=]
function RoguePropertyTableDefinition:GetContainer(serviceBag, adornee)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	if serviceBag:GetService(RoguePropertyService):CanInitializeProperties() then
		return self:_ensureContainer(adornee)
	else
		return adornee:FindFirstChild(self._tableName)
	end
end

function RoguePropertyTableDefinition:_ensureContainer(adornee)
	local existing = adornee:FindFirstChild(self._tableName)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = self._tableName
	folder.Parent = adornee
	return folder
end

function RoguePropertyTableDefinition:__index(index)
	assert(type(index) == "string", "Bad index")

	if index == "_definitionMap" then
		return rawget(self, "_definitionMap")
	elseif RoguePropertyTableDefinition[index] then
		return RoguePropertyTableDefinition[index]
	else
		local definitions = rawget(self, "_definitionMap")

		if definitions[index] then
			return definitions[index]
		else
			error(("Bad definition %q"):format(tostring(index)))
		end
	end
end

return RoguePropertyTableDefinition