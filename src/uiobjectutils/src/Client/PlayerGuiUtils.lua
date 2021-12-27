--[=[
	@class PlayerGuiUtils
]=]

local Players = game:GetService("Players")

local PlayerGuiUtils = {}

function PlayerGuiUtils.getPlayerGui()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		error("No localPlayer")
	end

	return localPlayer:FindFirstChildOfClass("PlayerGui") or error("No PlayerGui")
end

return PlayerGuiUtils