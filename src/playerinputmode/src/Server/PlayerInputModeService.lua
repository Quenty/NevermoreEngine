--!strict
--[=[
	Reports back the player input mode to the server which allows for displaying what
	mode the uesr is using.

	@server
	@class PlayerInputModeService
]=]

local require = require(script.Parent.loader).load(script)

local GetRemoteEvent = require("GetRemoteEvent")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerInputModeServiceConstants = require("PlayerInputModeServiceConstants")
local PlayerInputModeUtils = require("PlayerInputModeUtils")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local PlayerInputModeService = {}
PlayerInputModeService.ServiceName = "PlayerInputModeService"

export type PlayerInputModeService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoteEvent: RemoteEvent,
	},
	{} :: typeof({ __index = PlayerInputModeService })
))

function PlayerInputModeService.Init(self: PlayerInputModeService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
end

function PlayerInputModeService.Start(self: PlayerInputModeService): ()
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
function PlayerInputModeService.GetPlayerInputModeType(
	_self: PlayerInputModeService,
	player: Player
): PlayerInputModeUtils.PlayerInputModeType?
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerInputModeUtils.getPlayerInputModeType(player)
end

--[=[
	Promises the player input mode type from the player

	@param player Player
	@param cancelToken CancelToken
	@return Promise<PlayerInputModeType>
]=]
function PlayerInputModeService.PromisePlayerInputMode(
	_self: PlayerInputModeService,
	player: Player,
	cancelToken: any?
): Promise.Promise<PlayerInputModeUtils.PlayerInputModeType?>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerInputModeUtils.promisePlayerInputMode(player, cancelToken)
end

--[=[
	Observes the player input mode type from the player

	@param player Player
	@return Observable<PlayerInputModeType>
]=]
function PlayerInputModeService.ObservePlayerInputType(
	_self: PlayerInputModeService,
	player: Player
): Observable.Observable<PlayerInputModeUtils.PlayerInputModeType?>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerInputModeUtils.observePlayerInputModeType(player)
end

function PlayerInputModeService._handleServerEvent(
	self: PlayerInputModeService,
	player: Player,
	request: any,
	...: any
): ()
	if request == PlayerInputModeServiceConstants.REQUEST_SET_INPUT_MODE then
		self:_setPlayerInputModeType(player, ...)
	else
		error(string.format("[PlayerInputModeService] - Bad request %q", tostring(request)))
	end
end

function PlayerInputModeService._setPlayerInputModeType(
	_self: PlayerInputModeService,
	player: Player,
	inputModeType: any
): ()
	assert(PlayerInputModeUtils.isInputModeType(inputModeType), "Bad inputModeType")

	PlayerInputModeUtils.setPlayerInputModeType(player, inputModeType)
end

return PlayerInputModeService
