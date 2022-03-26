--[=[
	@class RoguePropertyTable
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local RoguePropertyTable = {}
RoguePropertyTable.ClassName = "RoguePropertyTable"
RoguePropertyTable.__index = RoguePropertyTable

function RoguePropertyTable.new(adornee, serviceBag, roguePropertyTableDefinition)
	local self = setmetatable({}, RoguePropertyTable)

	self._adornee = assert(adornee, "No roguePropertyTableDefinition")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._definition = assert(roguePropertyTableDefinition, "No roguePropertyTableDefinition")

	self._properties = {}

	if RunService:IsServer() then
		self:_setup()
	end

	return self
end

function RoguePropertyTable:ObserveContainerBrio()
	return self._definition:ObserveContainerBrio(self._serviceBag, self._adornee)
end

function RoguePropertyTable:GetContainer()
	return self._definition:GetContainer(self._serviceBag, self._adornee)
end

function RoguePropertyTable:Set(newBaseValues)
	assert(type(newBaseValues) == "table", "Bad newBaseValues")

	for propertyName, value in pairs(newBaseValues) do
		local rogueProperty = self:GetRogueProperty(propertyName)
		if not rogueProperty then
			error(("Bad property %q"):format(tostring(propertyName)))
		end

		rogueProperty:SetBaseValue(value)
	end
end

function RoguePropertyTable:_setup()
	for definitionName, _ in pairs(self._definition:GetDefinitionMap()) do
		self:GetRogueProperty(definitionName)
	end
end

function RoguePropertyTable:GetRogueProperty(name)
	-- Caching these things doesn't do a whole lot, but saves on table allocation.
	if self._properties[name] then
		return self._properties[name]
	end

	local definition = self._definition:GetDefinition(name)
	if definition then
		self._properties[name] = definition:Get(self._serviceBag, self._adornee)
		return self._properties[name]
	else
		return nil
	end
end

function RoguePropertyTable:__index(index)
	assert(type(index) == "string", "Bad index")

	if RoguePropertyTable[index] then
		return RoguePropertyTable[index]
	elseif type(index) == "string" then
		local property = self:GetRogueProperty(index)
		if not property then
			error(("Bad index %q"):format(tostring(index)))
		end
		return property
	else
		error(("Bad index %q"):format(tostring(index)))
	end
end

return RoguePropertyTable