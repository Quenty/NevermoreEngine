--!strict
--[=[
	@class TieSignalDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMemberDefinition = require("TieMemberDefinition")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")
local TieSignalImplementation = require("TieSignalImplementation")
local TieSignalInterface = require("TieSignalInterface")

local TieSignalDefinition = setmetatable({}, TieMemberDefinition)
TieSignalDefinition.ClassName = "TieSignalDefinition"
TieSignalDefinition.__index = TieSignalDefinition

export type TieSignalDefinition =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = TieSignalDefinition })))
	& TieMemberDefinition.TieMemberDefinition

function TieSignalDefinition.new(
	tieDefinition: any,
	signalName: string,
	memberTieRealm: TieRealms.TieRealm
): TieSignalDefinition
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self: TieSignalDefinition =
		setmetatable(TieMemberDefinition.new(tieDefinition, signalName, memberTieRealm) :: any, TieSignalDefinition)

	return self
end

function TieSignalDefinition.Implement(
	self: TieSignalDefinition,
	implParent: Instance,
	initialValue: any,
	_actualSelf: any,
	tieRealm: TieRealms.TieRealm
): TieSignalImplementation.TieSignalImplementation
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieSignalImplementation.new(self, implParent, initialValue)
end

function TieSignalDefinition.GetInterface(
	self: TieSignalDefinition,
	implParent: Instance,
	_actualSelf: any,
	tieRealm: TieRealms.TieRealm
): TieSignalInterface.TieSignalInterface
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TieSignalInterface.new(implParent, nil, self, tieRealm)
end

return TieSignalDefinition
