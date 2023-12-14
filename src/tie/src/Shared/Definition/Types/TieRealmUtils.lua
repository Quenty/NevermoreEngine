--[=[
	@class TieRealmUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local TieRealms = require("TieRealms")

local TieRealmUtils = {}

function TieRealmUtils.isRequired(tieRealm)
	if tieRealm == TieRealms.CLIENT then
		-- Hack: TODO: Maybe we should contextualize the realm throughout all callers.
		-- But otherwise, we'll need to do this
		if not RunService:IsRunning() then
			return false
		end

		return RunService:IsClient()
	elseif tieRealm == TieRealms.SERVER then
		-- Hack: TODO: Maybe we should contextualize the realm throughout all callers.
		-- But otherwise, we'll need to do this
		if not RunService:IsRunning() then
			return false
		end

		return RunService:IsServer()
	elseif tieRealm == TieRealms.SHARED then
		return true
	else
		error("Unknown tieRealm")
	end
end

function TieRealmUtils.isAllowed(tieRealm)
	if tieRealm == TieRealms.CLIENT then
		-- Hack: TODO: Maybe we should contextualize the realm throughout all callers.
		-- But otherwise, we'll need to do this
		if not RunService:IsRunning() then
			return true
		end

		return RunService:IsClient()
	elseif tieRealm == TieRealms.SERVER then
		-- Hack: TODO: Maybe we should contextualize the realm throughout all callers.
		-- But otherwise, we'll need to do this
		if not RunService:IsRunning() then
			return true
		end

		return RunService:IsServer()
	elseif tieRealm == TieRealms.SHARED then
		return true
	else
		error("Unknown tieRealm")
	end
end

return TieRealmUtils