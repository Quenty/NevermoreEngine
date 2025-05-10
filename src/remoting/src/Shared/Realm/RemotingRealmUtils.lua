--!strict
--[=[
	@class RemotingRealmUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local RemotingRealms = require("RemotingRealms")

local RemotingRealmUtils = {}

function RemotingRealmUtils.isRemotingRealm(realm: any): boolean
	return realm == RemotingRealms.SERVER or realm == RemotingRealms.CLIENT
end

function RemotingRealmUtils.inferRemotingRealm(): RemotingRealms.RemotingRealm
	if RunService:IsServer() then
		return RemotingRealms.SERVER
	elseif RunService:IsClient() then
		return RemotingRealms.CLIENT
	else
		error("[RemotingRealmUtils.inferRemotingRealm] - Unknown RunService state")
	end
end

return RemotingRealmUtils
