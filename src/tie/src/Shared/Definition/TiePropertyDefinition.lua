--[=[
	@class TiePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TiePropertyImplementation = require("TiePropertyImplementation")
local TiePropertyInterface = require("TiePropertyInterface")

local TiePropertyDefinition = setmetatable({}, BaseObject)
TiePropertyDefinition.ClassName = "TiePropertyDefinition"
TiePropertyDefinition.__index = TiePropertyDefinition

function TiePropertyDefinition.new(tieDefinition, propertyName: string, defaultValue: any)
	local self = setmetatable(BaseObject.new(), TiePropertyDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._propertyName = assert(propertyName, "No propertyName")
	self._defaultValue = defaultValue

	return self
end

function TiePropertyDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TiePropertyDefinition:IsAttribute()
	return self._isAttribute
end

function TiePropertyDefinition:GetDefaultValue()
	return self._defaultValue
end

function TiePropertyDefinition:Implement(folder: Folder, initialValue)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TiePropertyImplementation.new(self, folder, initialValue)
end

function TiePropertyDefinition:GetInterface(folder: Folder)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TiePropertyInterface.new(folder, nil, self)
end

function TiePropertyDefinition:GetMemberName(): string
	return self._propertyName
end

return TiePropertyDefinition