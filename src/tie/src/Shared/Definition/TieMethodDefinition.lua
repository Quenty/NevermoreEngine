--[=[
	@class TieMethodDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMethodImplementation = require("TieMethodImplementation")
local TieMethodInterfaceUtils = require("TieMethodInterfaceUtils")

local TieMethodDefinition = {}
TieMethodDefinition.ClassName = "TieMethodDefinition"
TieMethodDefinition.__index = TieMethodDefinition

function TieMethodDefinition.new(tieDefinition, methodName)
	local self = setmetatable({}, TieMethodDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._methodName = assert(methodName, "No methodName")

	return self
end

function TieMethodDefinition:Implement(folder, initialValue, actualSelf)
	assert(typeof(folder) == "Instance", "Bad folder")
	assert(actualSelf, "No actualSelf")

	return TieMethodImplementation.new(self, folder, initialValue, actualSelf)
end

function TieMethodDefinition:GetInterface(folder: Folder, aliasSelf)
	assert(typeof(folder) == "Instance", "Bad folder")
	assert(aliasSelf, "No aliasSelf")

	return TieMethodInterfaceUtils.get(aliasSelf, self._tieDefinition, self, folder, nil)
end


function TieMethodDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieMethodDefinition:GetMemberName()
	return self._methodName
end

return TieMethodDefinition