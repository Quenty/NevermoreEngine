--[=[
	Reports back the player input mode to the server which allows for displaying what
	mode the uesr is using.

	@client
	@class PlayerInputModeServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local InputModeTypes = require("InputModeTypes")
local InputModeTypeSelector = require("InputModeTypeSelector")
local Maid = require("Maid")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local Rx = require("Rx")
local PlayerInputModeUtils = require("PlayerInputModeUtils")
local PlayerInputModeTypes = require("PlayerInputModeTypes")
local RxPlayerUtils = require("RxPlayerUtils")
local RxBrioUtils = require("RxBrioUtils")
local _ServiceBag = require("ServiceBag")

local PlayerInputModeServiceClient = {}
PlayerInputModeServiceClient.ServiceName = "PlayerInputModeServiceClient"

function PlayerInputModeServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("InputModeServiceClient"))

	self._maid = Maid.new()
end

function PlayerInputModeServiceClient:Start()
	self._selector = self._maid:Add(InputModeTypeSelector.new(self._serviceBag, {
		InputModeTypes.Gamepads,
		InputModeTypes.Keyboard,
		InputModeTypes.Touch
	}))

	self:_promiseRemoteEvent():Then(function(remoteEvent)
		self._maid:GiveTask(RxBrioUtils.flatCombineLatest({
			activeMode = self._selector:ObserveActiveInputType();
			localPlayer = RxPlayerUtils.observeLocalPlayerBrio();
		}):Pipe({
			Rx.throttleTime(1, { leading = true; trailing = true });
		}):Subscribe(function(state)
			local modeType
			if state.activeMode == InputModeTypes.Gamepads then
				modeType = PlayerInputModeTypes.GAMEPAD
			elseif state.activeMode == InputModeTypes.Keyboard then
				modeType = PlayerInputModeTypes.KEYBOARD
			elseif state.activeMode == InputModeTypes.Touch then
				modeType = PlayerInputModeTypes.TOUCH
			else
				error("Bad activeMode")
			end

			if state.localPlayer then
				PlayerInputModeUtils.setPlayerInputModeType(state.localPlayer, modeType)
				remoteEvent:FireServer(PlayerInputModeServiceConstants.REQUEST_SET_INPUT_MODE, modeType)
			end
		end))
	end)
end

--[=[
	Observes the player input mode type from the player

	@param player Player
	@return Observable<PlayerInputModeType>
]=]
function PlayerInputModeServiceClient:ObservePlayerInputType(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.observePlayerInputModeType(player)
end

--[=[
	Gets the player input mode type from the player

	@param player Player
	@return PlayerInputModeType
]=]
function PlayerInputModeServiceClient:GetPlayerInputModeType(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.getPlayerInputModeType(player)
end

function PlayerInputModeServiceClient:_promiseRemoteEvent()
	return self._maid:GivePromise(PromiseGetRemoteEvent(PlayerInputModeServiceConstants.REMOTE_EVENT_NAME))
end

function PlayerInputModeServiceClient:Destroy()
	self._maid:DoCleaning()
end

return PlayerInputModeServiceClient