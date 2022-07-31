--[=[
	@class PlayerInputModeServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local INPUT_MODES = require("INPUT_MODES")
local InputModeSelector = require("InputModeSelector")
local Maid = require("Maid")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local Rx = require("Rx")
local PlayerInputModeUtils = require("PlayerInputModeUtils")
local PlayerInputModeTypes = require("PlayerInputModeTypes")

local PlayerInputModeServiceClient = {}

function PlayerInputModeServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
end

function PlayerInputModeServiceClient:Start()
	self._selector = InputModeSelector.new({
		INPUT_MODES.Gamepads,
		INPUT_MODES.Keyboard,
		INPUT_MODES.Touch
	})
	self._maid:GiveTask(self._selector)

	self:_promiseRemoteEvent():Then(function(remoteEvent)
		self._maid:GiveTask(self._selector:ObserveActiveMode():Pipe({
			Rx.throttleTime(1, { leading = true; trailing = true });
		}):Subscribe(function(activeMode)
			local modeType
			if activeMode == INPUT_MODES.Gamepads then
				modeType = PlayerInputModeTypes.GAMEPAD
			elseif activeMode == INPUT_MODES.Keyboard then
				modeType = PlayerInputModeTypes.KEYBOARD
			elseif activeMode == INPUT_MODES.Touch then
				modeType = PlayerInputModeTypes.TOUCH
			else
				error("Bad activeMode")
			end

			PlayerInputModeUtils.setPlayerInputModeType(Players.LocalPlayer, modeType)
			remoteEvent:FireServer(PlayerInputModeServiceConstants.REQUEST_SET_INPUT_MODE, modeType)
		end))
	end)
end

function PlayerInputModeServiceClient:ObservePlayerInputType(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.observePlayerInputModeType(player)
end

function PlayerInputModeServiceClient:GetPlayerInputModeType(player)
	return PlayerInputModeUtils.getPlayerInputModeType(player)
end

function PlayerInputModeServiceClient:_promiseRemoteEvent()
	return self._maid:GivePromise(PromiseGetRemoteEvent(PlayerInputModeServiceConstants.REMOTE_EVENT_NAME))
end

function PlayerInputModeServiceClient:Destroy()
	self._maid:DoCleaning()
end

return PlayerInputModeServiceClient