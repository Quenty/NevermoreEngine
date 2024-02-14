--[=[
	@class PlayerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")

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

	return PlayerUtils.formatDisplayName(name, displayName)
end

--[=[
	Human-readable version of a player name. If the player's name is the same
	as the display name, then returns that player's name. Otherwise returns
	a formatted name with the player's name like this "oot (@martxn)" which
	lets you know the username and the display name.

	Note this is not localized, although most languages should be ok. Great for
	output for dev logs and command services which are less picky.

	@param name string
	@param displayName string
	@return string -- Formatted name
]=]
function PlayerUtils.formatDisplayName(name, displayName)
	if name:lower() == displayName:lower() then
		return displayName
	else
		return ("%s (@%s)"):format(displayName, name)
	end
end

local NAME_COLORS = {
	BrickColor.new("Bright red").Color;
	BrickColor.new("Bright blue").Color;
	BrickColor.new("Earth green").Color;
	BrickColor.new("Bright violet").Color,
	BrickColor.new("Bright orange").Color,
	BrickColor.new("Bright yellow").Color,
	BrickColor.new("Light reddish violet").Color,
	BrickColor.new("Brick yellow").Color,
}

local function hashName(pName)
	local value = 0
	for index = 1, #pName do
		local cValue = string.byte(string.sub(pName, index, index))
		local reverseIndex = #pName - index + 1
		if #pName%2 == 1 then
			reverseIndex = reverseIndex - 1
		end
		if reverseIndex%4 >= 2 then
			cValue = -cValue
		end
		value = value + cValue
	end
	return value
end

--[=[
	Retrieves the display name color for a given player (for the Roblox chat)

	@param displayName string
	@return Color3
]=]
function PlayerUtils.getDefaultNameColor(displayName)
	return NAME_COLORS[(hashName(displayName) % #NAME_COLORS) + 1]
end

--[=[
	Calls :LoadCharacter() in a promise

	@param player Player
	@return Promise<Model>
]=]
function PlayerUtils.promiseLoadCharacter(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			return reject(err or "Failed to load character")
		end

		return resolve()
	end)
end

--[=[
	Calls :LoadCharacterWithHumanoidDescription() in a promise

	@param player Player
	@param humanoidDescription HumanoidDescription
	@return Promise<Model>
]=]
function PlayerUtils.promiseLoadCharacterWithHumanoidDescription(player, humanoidDescription)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"), "Bad humanoidDescription")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			player:LoadCharacterWithHumanoidDescription(humanoidDescription)
		end)
		if not ok then
			return reject(err or "Failed to load character")
		end

		return resolve()
	end)
end

return PlayerUtils
