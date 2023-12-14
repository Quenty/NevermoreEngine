--[=[
	@class TieSignalDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalImplementation = require("TieSignalImplementation")
local TieSignalInterface = require("TieSignalInterface")
local TieRealmUtils = require("TieRealmUtils")

local TieSignalDefinition = {}
TieSignalDefinition.ClassName = "TieSignalDefinition"
TieSignalDefinition.__index = TieSignalDefinition

function TieSignalDefinition.new(tieDefinition, signalName, realm)
	local self = setmetatable({}, TieSignalDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._signalName = assert(signalName, "No signalName")
	self._tieRealm = assert(realm, "No realm")
	self._isRequired = TieRealmUtils.isRequired(self._tieRealm)
	self._isAllowed = TieRealmUtils.isAllowed(self._tieRealm)

	return self
end

function TieSignalDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieSignalDefinition:IsRequired()
	return self._isRequired
end

function TieSignalDefinition:IsAllowed()
	return self._isAllowed
end

function TieSignalDefinition:GetTieRealm()
	return self._tieRealm
end

function TieSignalDefinition:Implement(folder, initialValue)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TieSignalImplementation.new(self, folder, initialValue)
end

function TieSignalDefinition:GetInterface(folder: Folder)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TieSignalInterface.new(folder, nil, self)
end

function TieSignalDefinition:GetMemberName()
	return self._signalName
end

return TieSignalDefinition