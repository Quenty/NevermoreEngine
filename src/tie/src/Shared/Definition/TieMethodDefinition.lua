--[=[
	@class TieMethodDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMethodDefinition = {}
TieMethodDefinition.ClassName = "TieMethodDefinition"
TieMethodDefinition.__index = TieMethodDefinition

function TieMethodDefinition.new(tieDefinition, methodName)
	local self = setmetatable({}, TieMethodDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._methodName = assert(methodName, "No methodName")

	return self
end

function TieMethodDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieMethodDefinition:GetMemberName()
	return self._methodName
end

return TieMethodDefinition