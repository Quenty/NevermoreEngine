--!strict
--[=[
	Utility methods to oeprate around [TieRealms]

	@class TieRealmUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local TieRealms = require("TieRealms")

local TieRealmUtils = {}

--[=[
	Returns true if the value is a tie realm

	@param tieRealm any
	@return boolean
]=]
function TieRealmUtils.isTieRealm(tieRealm: any): boolean
	-- stylua: ignore
	return tieRealm == TieRealms.CLIENT
		or tieRealm == TieRealms.SERVER
		or tieRealm == TieRealms.SHARED
end

--[=[
	Infers the tie realm from the current RunService state

	@return TieRealm
]=]
function TieRealmUtils.inferTieRealm(): "server" | "client"
	if RunService:IsServer() then
		return TieRealms.SERVER
	elseif RunService:IsClient() then
		return TieRealms.CLIENT
	else
		error("[TieRealmUtils.inferTieRealm] - Unknown RunService state")
	end
end

return TieRealmUtils
