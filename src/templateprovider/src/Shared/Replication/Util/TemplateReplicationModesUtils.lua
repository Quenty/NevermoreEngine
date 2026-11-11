--!strict
--[=[
	@class TemplateReplicationModesUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local TemplateReplicationModes = require("TemplateReplicationModes")
local TieRealms = require("TieRealms")

local TemplateReplicationModesUtils = {}

--[=[
	Returns the replication mode for a [TieRealm]
]=]
function TemplateReplicationModesUtils.fromTieRealm(
	tieRealm: TieRealms.TieRealm
): TemplateReplicationModes.TemplateReplicationMode
	if tieRealm == TieRealms.SERVER then
		return TemplateReplicationModes.SERVER
	elseif tieRealm == TieRealms.CLIENT then
		return TemplateReplicationModes.CLIENT
	elseif tieRealm == TieRealms.SHARED then
		return TemplateReplicationModes.SHARED
	else
		error("Bad tieRealm")
	end
end

--[=[
	Uses run service to infer the replication mode
]=]
function TemplateReplicationModesUtils.inferReplicationMode(): TemplateReplicationModes.TemplateReplicationMode
	if not RunService:IsRunning() then
		return TemplateReplicationModes.SHARED
	end

	if RunService:IsServer() then
		return TemplateReplicationModes.SERVER
	elseif RunService:IsClient() then
		return TemplateReplicationModes.CLIENT
	else
		return TemplateReplicationModes.SHARED
	end
end

return TemplateReplicationModesUtils
