--!strict
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

export type TieMethodDefinition =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = TieMethodDefinition })))
	& TieMemberDefinition.TieMemberDefinition

function TieMethodDefinition.new(
	tieDefinition: any,
	methodName: string,
	memberTieRealm: TieRealms.TieRealm
): TieMethodDefinition
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self: TieMethodDefinition =
		setmetatable(TieMemberDefinition.new(tieDefinition, methodName, memberTieRealm) :: any, TieMethodDefinition)

	return self
end

function TieMethodDefinition.GetFriendlyName(self: TieMethodDefinition): string
	return string.format("%s:%s()", self._tieDefinition:GetName(), self._memberName)
end

function TieMethodDefinition.Implement(
	self: TieMethodDefinition,
	implParent: Instance,
	initialValue: any,
	actualSelf: any,
	tieRealm: TieRealms.TieRealm
): TieMethodImplementation.TieMethodImplementation
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(actualSelf, "No actualSelf")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieMethodImplementation.new(self, implParent, initialValue, actualSelf)
end

function TieMethodDefinition.GetInterface(
	self: TieMethodDefinition,
	implParent: Instance,
	aliasSelf: any,
	tieRealm: TieRealms.TieRealm
): (any, ...any) -> ...any
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(aliasSelf, "No aliasSelf")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieMethodInterfaceUtils.get(aliasSelf, self, implParent, nil, tieRealm)
end

return TieMethodDefinition
