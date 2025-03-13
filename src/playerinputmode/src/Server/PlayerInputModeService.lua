--[=[
	Reports back the player input mode to the server which allows for displaying what
	mode the uesr is using.

	@server
	@class PlayerInputModeService
]=]

local require = require(script.Parent.loader).load(script)

local GetRemoteEvent  = require("GetRemoteEvent")
local Maid = require("Maid")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PlayerInputModeUtils = require("PlayerInputModeUtils")
local _ServiceBag = require("ServiceBag")

local PlayerInputModeService = {}
PlayerInputModeService.ServiceName = "PlayerInputModeService"

function PlayerInputModeService:Init(serviceBag: _ServiceBag.ServiceBag)
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

--[=[
	Gets the player input mode type from the player

	@param player Player
	@return PlayerInputModeType
]=]
function PlayerInputModeService:GetPlayerInputModeType(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.getPlayerInputModeType(player)
end

--[=[
	Promises the player input mode type from the player

	@param player Player
	@param cancelToken CancelToken
	@return Promise<PlayerInputModeType>
]=]
function PlayerInputModeService:PromisePlayerInputMode(player: Player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.promisePlayerInputMode(player, cancelToken)
end

--[=[
	Observes the player input mode type from the player

	@param player Player
	@return Observable<PlayerInputModeType>
]=]
function PlayerInputModeService:ObservePlayerInputType(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerInputModeUtils.observePlayerInputModeType(player)
end

function PlayerInputModeService:_handleServerEvent(player: Player, request, ...)
	if request == PlayerInputModeServiceConstants.REQUEST_SET_INPUT_MODE then
		self:_setPlayerInputModeType(player, ...)
	else
		error(string.format("[PlayerInputModeService] - Bad request %q", tostring(request)))
	end
end

function PlayerInputModeService:_setPlayerInputModeType(player: Player, inputModeType)
	assert(PlayerInputModeUtils.isInputModeType(inputModeType), "Bad inputModeType")

	PlayerInputModeUtils.setPlayerInputModeType(player, inputModeType)
end


return PlayerInputModeService