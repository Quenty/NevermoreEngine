--[=[
	@class PlayerInputModeService
]=]

local require = require(script.Parent.loader).load(script)

local GetRemoteEvent  = require("GetRemoteEvent")
local Maid = require("Maid")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PlayerInputModeUtils = require("PlayerInputModeUtils")

local PlayerInputModeService = {}
PlayerInputModeService.ServiceName = "PlayerInputModeService"

function PlayerInputModeService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
end

function PlayerInputModeService:Start()
	self._remoteEvent = GetRemoteEvent(PlayerInputModeServiceConstants.REMOTE_EVENT_NAME)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_handleServerEvent(...)
	end))
end

function PlayerInputModeService:GetPlayerInputModeType(player)
	return PlayerInputModeUtils.getPlayerInputModeType(player)
end

function PlayerInputModeService:PromisePlayerInputMode(player, cancelToken)
	return PlayerInputModeUtils.promisePlayerInputMode(player, cancelToken)
end

function PlayerInputModeService:ObservePlayerInputType(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.observePlayerInputModeType(player)
end

function PlayerInputModeService:_handleServerEvent(player, request, ...)
	if request == PlayerInputModeServiceConstants.REQUEST_SET_INPUT_MODE then
		self:_setPlayerInputModeType(player, ...)
	else
		error(("[PlayerInputModeService] - Bad request %q"):format(tostring(request)))
	end
end

function PlayerInputModeService:_setPlayerInputModeType(player, inputModeType)
	assert(PlayerInputModeUtils.isInputModeType(inputModeType), "Bad inputModeType")

	PlayerInputModeUtils.setPlayerInputModeType(player, inputModeType)
end


return PlayerInputModeService