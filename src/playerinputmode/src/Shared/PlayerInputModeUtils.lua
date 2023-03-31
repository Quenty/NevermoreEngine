--[=[
	@class PlayerInputModeUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local RxAttributeUtils = require("RxAttributeUtils")
local PlayerInputModeTypes = require("PlayerInputModeTypes")
local AttributeUtils = require("AttributeUtils")

local PlayerInputModeUtils = {}

function PlayerInputModeUtils.getPlayerInputModeType(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return player:GetAttribute(PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE)
end

function PlayerInputModeUtils.observePlayerInputModeType(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return RxAttributeUtils.observeAttribute(player, PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE)
end

function PlayerInputModeUtils.promisePlayerInputMode(player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return AttributeUtils.promiseAttribute(player, PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE, PlayerInputModeUtils.isInputModeType, cancelToken)
end

function PlayerInputModeUtils.isInputModeType(playerInputModeType)
	return typeof(playerInputModeType) == "string" and (
		playerInputModeType == PlayerInputModeTypes.GAMEPAD
		or playerInputModeType == PlayerInputModeTypes.KEYBOARD
		or playerInputModeType == PlayerInputModeTypes.TOUCH)
end

function PlayerInputModeUtils.setPlayerInputModeType(player, playerInputModeType)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PlayerInputModeUtils.isInputModeType(playerInputModeType), "Bad playerInputModeType")

	player:SetAttribute(PlayerInputModeServiceConstants.INPUT_MODE_ATTRIBUTE, playerInputModeType)
end

return PlayerInputModeUtils