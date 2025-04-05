--[=[
	Utility methods to track public player input mode

	@class PlayerInputModeUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PlayerInputModeTypes = require("PlayerInputModeTypes")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")

local PlayerInputModeUtils = {}

export type PlayerInputModeType = "Gamepad" | "Keyboard" | "Touch"

--[=[
	Returns the player input mode type for a player.

	@param player Player
	@return PlayerInputModeType?
]=]
function PlayerInputModeUtils.getPlayerInputModeType(player: Player): PlayerInputModeType?
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local result = player:GetAttribute(PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE)
	if PlayerInputModeUtils.isInputModeType(result) then
		return result
	else
		return nil
	end
end

--[=[
	Observes the player input mode type for a player.

	@param player Player
	@return Observable<PlayerInputModeType?>
]=]
function PlayerInputModeUtils.observePlayerInputModeType(player: Player): PlayerInputModeType?
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return RxAttributeUtils.observeAttribute(player, PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE):Pipe({
		Rx.map(function(value)
			if PlayerInputModeUtils.isInputModeType(value) then
				return value
			else
				return nil
			end
		end),
	})
end

--[=[
	Observes the player input mode type for a player.

	@param player Player
	@param cancelToken CancelToken?
	@return Promise<string?>
]=]
function PlayerInputModeUtils.promisePlayerInputMode(player: Player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return AttributeUtils.promiseAttribute(
		player,
		PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE,
		PlayerInputModeUtils.isInputModeType,
		cancelToken
	)
end

--[=[
	Checks if the input mode type is valid.

	@param playerInputModeType any
	@return boolean
]=]
function PlayerInputModeUtils.isInputModeType(playerInputModeType: any): boolean
	return typeof(playerInputModeType) == "string"
		and (
			playerInputModeType == PlayerInputModeTypes.GAMEPAD
			or playerInputModeType == PlayerInputModeTypes.KEYBOARD
			or playerInputModeType == PlayerInputModeTypes.TOUCH
		)
end

--[=[
	Sets the player input mode type for a player.

	@param player Player
	@param playerInputModeType string
]=]
function PlayerInputModeUtils.setPlayerInputModeType(player: Player, playerInputModeType: PlayerInputModeType)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PlayerInputModeUtils.isInputModeType(playerInputModeType), "Bad playerInputModeType")

	player:SetAttribute(PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE, playerInputModeType)
end

return PlayerInputModeUtils