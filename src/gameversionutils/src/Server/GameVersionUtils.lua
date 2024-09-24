--[=[
	Utility functions to automatically detect the version a game is running at
	@class GameVersionUtils
]=]

local RunService = game:GetService("RunService")

local GameVersionUtils = {}

--[=[
	Gets the game build
	@return string
]=]
function GameVersionUtils.getBuild()
	if RunService:IsStudio() then
		return "studio"
	else
		return string.format("%d", game.PlaceVersion)
	end
end

--[=[
	Gets the game build with a server type specified for debugging
	@return string
]=]
function GameVersionUtils.getBuildWithServerType()
	return GameVersionUtils.getBuild() .. "-" .. GameVersionUtils.getServerType()
end

--[=[
	Gets a string label for the current server type
	@return string
]=]
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

--[=[
	Returns true if we're a VIP server
	@return boolean
]=]
function GameVersionUtils.isVIPServer()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

return GameVersionUtils