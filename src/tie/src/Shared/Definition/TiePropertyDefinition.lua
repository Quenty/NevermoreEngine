--[=[
	@class TiePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local TiePropertyDefinition = setmetatable({}, BaseObject)
TiePropertyDefinition.ClassName = "TiePropertyDefinition"
TiePropertyDefinition.__index = TiePropertyDefinition

function TiePropertyDefinition.new(tieDefinition, propertyName: string)
	local self = setmetatable(BaseObject.new(), TiePropertyDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._propertyName = assert(propertyName, "No propertyName")

	return self
end

function TiePropertyDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TiePropertyDefinition:GetMemberName(): string
	return self._propertyName
end

return TiePropertyDefinition