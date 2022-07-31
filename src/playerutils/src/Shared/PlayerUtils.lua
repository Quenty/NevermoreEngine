--[=[
	@class PlayerUtils
]=]

local PlayerUtils = {}

--[=[
	Human-readable version of a player name. If the player's name is the same
	as the display name, then returns that player's name. Otherwise returns
	a formatted name with the player's name like this "oot (@martxn)" which
	lets you know the username and the display name.

	Note this is not localized, although most languages should be ok. Great for
	output for dev logs and command services which are less picky.

	@param player Player
	@return string -- Formatted name
]=]
function PlayerUtils.formatName(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local name = player.Name
	local displayName = player.DisplayName

	if name:lower() == displayName:lower() then
		return displayName
	else
		return ("%s (@%s)"):format(displayName, name)
	end
end

return PlayerUtils