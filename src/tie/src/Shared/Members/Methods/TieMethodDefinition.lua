--[=[
	@class TieMethodDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMemberDefinition = require("TieMemberDefinition")
local TieMethodImplementation = require("TieMethodImplementation")
local TieMethodInterfaceUtils = require("TieMethodInterfaceUtils")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")

local TieMethodDefinition = setmetatable({}, TieMemberDefinition)
TieMethodDefinition.ClassName = "TieMethodDefinition"
TieMethodDefinition.__index = TieMethodDefinition

function TieMethodDefinition.new(tieDefinition, methodName: string, memberTieRealm: TieRealms.TieRealm)
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self = setmetatable(TieMemberDefinition.new(tieDefinition, methodName, memberTieRealm), TieMethodDefinition)

	return self
end

function TieMethodDefinition:GetFriendlyName(): string
	return string.format("%s:%s()", self._tieDefinition:GetName(), self._memberName)
end

function TieMethodDefinition:Implement(implParent: Instance, initialValue, actualSelf, tieRealm: TieRealms.TieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(actualSelf, "No actualSelf")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieMethodImplementation.new(self, implParent, initialValue, actualSelf)
end

function TieMethodDefinition:GetInterface(implParent: Instance, aliasSelf, tieRealm: TieRealms.TieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(aliasSelf, "No aliasSelf")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieMethodInterfaceUtils.get(aliasSelf, self, implParent, nil, tieRealm)
end

return TieMethodDefinition
