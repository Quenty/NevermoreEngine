--!strict
--[=[
	Base class for a member definition/declaration.

	@class TieMemberDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")

local TieMemberDefinition = {}
TieMemberDefinition.ClassName = "TieMemberDefinition"
TieMemberDefinition.__index = TieMemberDefinition

export type TieMemberDefinition = typeof(setmetatable(
	{} :: {
		_tieDefinition: any,
		_memberName: string,
		_memberTieRealm: TieRealms.TieRealm,
	},
	{} :: typeof({ __index = TieMemberDefinition })
))

function TieMemberDefinition.new(
	tieDefinition: any,
	memberName: string,
	memberTieRealm: TieRealms.TieRealm
): TieMemberDefinition
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self: TieMemberDefinition = setmetatable({} :: any, TieMemberDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._memberName = assert(memberName, "Bad memberName")
	self._memberTieRealm = assert(memberTieRealm, "No memberTieRealm")

	return self
end

function TieMemberDefinition:Implement()
	error("Not implemented")
end

function TieMemberDefinition:GetInterface()
	error("Not implemented")
end

function TieMemberDefinition:GetFriendlyName(): string
	return string.format("%s.%s", self._tieDefinition:GetName(), self._memberName)
end

function TieMemberDefinition:IsRequiredForInterface(currentRealm: TieRealms.TieRealm): boolean
	assert(TieRealmUtils.isTieRealm(currentRealm), "Bad currentRealm")

	if self._memberTieRealm == TieRealms.SHARED then
		return true
	elseif currentRealm == TieRealms.SHARED then
		-- Interface can retrieve just the smallest subset... can allow cross sharing unfortunately....
		return false
	else
		return self._memberTieRealm == currentRealm
	end
end

function TieMemberDefinition:IsAllowedOnInterface(currentRealm: TieRealms.TieRealm): boolean
	assert(TieRealmUtils.isTieRealm(currentRealm), "Bad currentRealm")

	if self._memberTieRealm == TieRealms.SHARED then
		return true
	elseif currentRealm == TieRealms.SHARED then
		-- Allow these to be used on interface if they exist...
		return true
	else
		return self._memberTieRealm == currentRealm
	end
end

function TieMemberDefinition:IsRequiredForImplementation(currentRealm: TieRealms.TieRealm): boolean
	assert(TieRealmUtils.isTieRealm(currentRealm), "Bad currentRealm")

	if currentRealm == TieRealms.SHARED then
		-- Require both client and server if we're shared to be implemented
		return true
	elseif self._memberTieRealm == TieRealms.SHARED then
		return true
	else
		return self._memberTieRealm == currentRealm
	end
end

function TieMemberDefinition:IsAllowedForImplementation(currentRealm: TieRealms.TieRealm): boolean
	assert(TieRealmUtils.isTieRealm(currentRealm), "Bad currentRealm")

	if self._memberTieRealm == TieRealms.SHARED then
		return true
	elseif currentRealm == TieRealms.SHARED then
		-- Allowed
		return true
	else
		return self._memberTieRealm == currentRealm
	end
end

function TieMemberDefinition:GetMemberTieRealm(): TieRealms.TieRealm
	return self._memberTieRealm
end

function TieMemberDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieMemberDefinition:GetMemberName(): string
	return self._memberName
end

return TieMemberDefinition
