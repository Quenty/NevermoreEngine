--[=[
	@class TemplateReplicationModesUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local TemplateReplicationModes = require("TemplateReplicationModes")

local TemplateReplicationModesUtils = {}

function TemplateReplicationModesUtils.inferReplicationMode()
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