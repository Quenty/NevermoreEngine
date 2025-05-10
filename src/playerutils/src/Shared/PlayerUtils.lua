--!strict
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
function PlayerUtils.formatName(player: Player): string
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
function PlayerUtils.formatDisplayName(name: string, displayName: string): string
	if string.lower(name) == string.lower(displayName) then
		return displayName
	else
		return string.format("%s (@%s)", displayName, name)
	end
end

export type UserInfo = {
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

--[=[
	Formats the display name from the user info
	@param userInfo UserInfo
	@return string
]=]
function PlayerUtils.formatDisplayNameFromUserInfo(userInfo: UserInfo): string
	assert(type(userInfo) == "table", "Bad userInfo")
	assert(type(userInfo.Username) == "string", "Bad userInfo.Username")
	assert(type(userInfo.DisplayName) == "string", "Bad userInfo.DisplayName")

	local result = PlayerUtils.formatDisplayName(userInfo.Username, userInfo.DisplayName)

	if userInfo.HasVerifiedBadge then
		return PlayerUtils.addVerifiedBadgeToName(result)
	end

	return result
end

--[=[
	Adds verified badges to the name

	@param name string
	@return string
]=]
function PlayerUtils.addVerifiedBadgeToName(name: string): string
	return string.format("%s %s", name, utf8.char(0xE000))
end

local NAME_COLORS: { Color3 } = {
	(BrickColor :: any).new("Bright red").Color,
	(BrickColor :: any).new("Bright blue").Color,
	(BrickColor :: any).new("Earth green").Color,
	(BrickColor :: any).new("Bright violet").Color,
	(BrickColor :: any).new("Bright orange").Color,
	(BrickColor :: any).new("Bright yellow").Color,
	(BrickColor :: any).new("Light reddish violet").Color,
	(BrickColor :: any).new("Brick yellow").Color,
}

local function hashName(playerName: string): number
	local value = 0
	for index = 1, #playerName do
		local cValue = string.byte(string.sub(playerName, index, index))
		local reverseIndex = #playerName - index + 1
		if #playerName % 2 == 1 then
			reverseIndex = reverseIndex - 1
		end
		if reverseIndex % 4 >= 2 then
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
function PlayerUtils.getDefaultNameColor(displayName: string): Color3
	return NAME_COLORS[(hashName(displayName) % #NAME_COLORS) + 1]
end

--[=[
	Calls :LoadCharacter() in a promise

	@param player Player
	@return Promise<Model>
]=]
function PlayerUtils.promiseLoadCharacter(player: Player): Promise.Promise<Model>
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
function PlayerUtils.promiseLoadCharacterWithHumanoidDescription(
	player: Player,
	humanoidDescription: HumanoidDescription
): Promise.Promise<Model>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(
		typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"),
		"Bad humanoidDescription"
	)

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
