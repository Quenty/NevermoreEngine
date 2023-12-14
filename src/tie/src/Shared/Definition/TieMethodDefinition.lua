--[=[
	@class TieMethodDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMethodImplementation = require("TieMethodImplementation")
local TieMethodInterfaceUtils = require("TieMethodInterfaceUtils")
local TieRealmUtils = require("TieRealmUtils")

local TieMethodDefinition = {}
TieMethodDefinition.ClassName = "TieMethodDefinition"
TieMethodDefinition.__index = TieMethodDefinition

function TieMethodDefinition.new(tieDefinition, methodName, realm)
	local self = setmetatable({}, TieMethodDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._methodName = assert(methodName, "No methodName")
	self._tieRealm = assert(realm, "No realm")
	self._isRequired = TieRealmUtils.isRequired(self._tieRealm)
	self._isAllowed = TieRealmUtils.isAllowed(self._tieRealm)

	return self
end

function TieMethodDefinition:IsRequired()
	return self._isRequired
end

function TieMethodDefinition:IsAllowed()
	return self._isAllowed
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

function TieMethodDefinition:GetTieRealm()
	return self._tieRealm
end

function TieMethodDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieMethodDefinition:GetMemberName()
	return self._methodName
end

return TieMethodDefinition