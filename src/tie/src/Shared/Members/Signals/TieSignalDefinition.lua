--[=[
	@class TieSignalDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMemberDefinition = require("TieMemberDefinition")
local TieRealmUtils = require("TieRealmUtils")
local TieSignalImplementation = require("TieSignalImplementation")
local TieSignalInterface = require("TieSignalInterface")

local TieSignalDefinition = setmetatable({}, TieMemberDefinition)
TieSignalDefinition.ClassName = "TieSignalDefinition"
TieSignalDefinition.__index = TieSignalDefinition

function TieSignalDefinition.new(tieDefinition, signalName: string, memberTieRealm)
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self = setmetatable(TieMemberDefinition.new(tieDefinition, signalName, memberTieRealm), TieSignalDefinition)

	return self
end

function TieSignalDefinition:Implement(implParent: Instance, initialValue, _actualSelf, tieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieSignalImplementation.new(self, implParent, initialValue, tieRealm)
end

function TieSignalDefinition:GetInterface(implParent: Instance, _actualSelf, tieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieSignalInterface.new(implParent, nil, self, tieRealm)
end

return TieSignalDefinition
