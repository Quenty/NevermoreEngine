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
local DuckTypeUtils = require("DuckTypeUtils")
local RxBrioUtils = require("RxBrioUtils")

local RoguePropertyTableDefinition = {} -- Inherits from RoguePropertyDefinition
RoguePropertyTableDefinition.ClassName = "RoguePropertyTableDefinition"
RoguePropertyTableDefinition.__index = RoguePropertyTableDefinition

function RoguePropertyTableDefinition.new(tableName: string, propertyDefinition: {[string]: any}, roguePropertyTableDefinition)
	assert(type(tableName) == "string", "Bad tableName")
	assert(type(propertyDefinition) == "table", "Bad propertyDefinition")

	local self = setmetatable(RoguePropertyDefinition.new(tableName, propertyDefinition, roguePropertyTableDefinition), RoguePropertyTableDefinition)

	self._definitionMap = {}

	for key, defaultValue in pairs(propertyDefinition) do
		if type(defaultValue) == "table" then
			if RoguePropertyDefinition.isRoguePropertyDefinition(defaultValue) then
				self._definitionMap[key] = defaultValue
			else
				self._definitionMap[key] = RoguePropertyTableDefinition.new(key, defaultValue, self)
			end
		else
			self._definitionMap[key] = RoguePropertyDefinition.new(key, defaultValue, self)
		end
	end

	return self
end

function RoguePropertyTableDefinition.isRoguePropertyTableDefinition(value)
	return DuckTypeUtils.isImplementation(RoguePropertyTableDefinition, value)
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
function RoguePropertyTableDefinition:Get(serviceBag, adornee)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return RoguePropertyTable.new(adornee, serviceBag, self)
end

RoguePropertyTableDefinition.GetPropertyTable = RoguePropertyTableDefinition.Get

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
	self:GetContainer(serviceBag, adornee)

	local parentDefinition = self:GetParentPropertyDefinition()
	if parentDefinition then
		return parentDefinition:ObserveContainerBrio(serviceBag, adornee)
			:Pipe({
				RxBrioUtils.switchMapBrio(function(parent)
					return RxInstanceUtils.observeLastNamedChildBrio(parent, "Folder", self:GetName())
				end)
			})
	else
		return RxInstanceUtils.observeLastNamedChildBrio(adornee, "Folder", self:GetName())
	end
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

	local parent
	local parentDefinition = self:GetParentPropertyDefinition()
	if parentDefinition then
		parent = parentDefinition:GetContainer(serviceBag, adornee)
	else
		parent = adornee
	end

	if not parent then
		return nil
	end

	if serviceBag:GetService(RoguePropertyService):CanInitializeProperties() then
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

function RoguePropertyTableDefinition:__index(index)
	assert(type(index) == "string", "Bad index")

	if index == "_definitionMap" then
		return rawget(self, "_definitionMap")
	elseif index == "_roguePropertyTableDefinition" then
		return rawget(self, "_roguePropertyTableDefinition")
	elseif RoguePropertyTableDefinition[index] then
		return RoguePropertyTableDefinition[index]
	elseif RoguePropertyDefinition[index] then
		return RoguePropertyDefinition[index]
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