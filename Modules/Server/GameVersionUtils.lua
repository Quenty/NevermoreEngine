---
-- @module GameVersionUtils
-- @author Quenty

local RunService = game:GetService("RunService")

local GameVersionUtils = {}

function GameVersionUtils.getBuild()
	if RunService:IsStudio() then
		return "studio"
	else
		return ("%d"):format(game.PlaceVersion)
	end
end

function GameVersionUtils.getBuildWithServerType()
	return GameVersionUtils.getBuild() .. "-" .. GameVersionUtils.getServerType()
end

function GameVersionUtils.getServerType()
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return "vip"
		else
			return "reserved"
		end
	else
		return "standard"
	end
end


return GameVersionUtils