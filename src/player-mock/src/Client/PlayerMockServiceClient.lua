--!strict
--[=[
	Client-side counterpart to [PlayerMockService] -- one instance stands in for one simulated
	client. Discovery and leak detection live in [PlayerMockServiceBase]: this service sees a server
	bag's mocks the way a real client sees the players the server admitted, and multiple client
	services (simulated clients) may coexist.

	A headless test has no `Players.LocalPlayer`, so a test designates a [PlayerMock] as the local
	player for the client realm. The service records the designation per instance -- *this* simulated
	client's local player, read back with [PlayerMockServiceClient.GetLocalPlayer] -- and mirrors it
	into the ambient global read by bag-less call sites
	(`Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()`).

	Designation may happen *before* the bag boots -- `PlayerMock.setMockedLocalPlayer(player)`
	directly, matching production where `Players.LocalPlayer` exists before any service runs -- and
	[Init] adopts the pre-boot designation as this client's local player, owning its cleanup. Note
	the ambient global holds a single designation, so concurrent simulated clients are distinct only
	through their services; ambient readers (e.g. dummy-mode Remoting) see the most recent
	designation.

	```lua
	local playerMockServiceClient = clientServiceBag:GetService(require("PlayerMockServiceClient"))
	playerMockServiceClient:SetLocalPlayer(player)
	```

	@client
	@class PlayerMockServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMock = require("PlayerMock")
local PlayerMockServiceBase = require("PlayerMockServiceBase")
local ServiceBag = require("ServiceBag")

local PlayerMockServiceClient = setmetatable({}, { __index = PlayerMockServiceBase })
PlayerMockServiceClient.ServiceName = "PlayerMockServiceClient"
PlayerMockServiceClient._consumedAttributeName = "PlayerMockConsumedClient"
PlayerMockServiceClient._allowConcurrentConsumers = true

function PlayerMockServiceClient:Init(serviceBag: ServiceBag.ServiceBag)
	PlayerMockServiceBase.Init(self :: any, serviceBag)

	local designated = PlayerMock.getMockedLocalPlayer()
	if designated ~= nil then
		self:_adoptLocalPlayer(designated)
	end
end

--[=[
	Designates the given [PlayerMock] as this simulated client's local player, and mirrors it into
	the ambient global. Cleared automatically when the service is destroyed (unless another mock has
	since taken the ambient designation over).

	@param player Player -- must be a PlayerMock
]=]
function PlayerMockServiceClient:SetLocalPlayer(player: Player)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")

	PlayerMock.setMockedLocalPlayer(player)
	self:_adoptLocalPlayer(player)
end

--[=[
	Returns this simulated client's local player -- the designation this service made or adopted at
	[Init] -- or nil. Unlike [PlayerMock.getMockedLocalPlayer], this survives another client service
	designating a different mock.

	@return Player?
]=]
function PlayerMockServiceClient:GetLocalPlayer(): Player?
	return self._localPlayer
end

function PlayerMockServiceClient:_adoptLocalPlayer(player: Player)
	self._localPlayer = player :: Player?
	self._maid:GiveTask(function()
		if self._localPlayer == player then
			self._localPlayer = nil
		end
		if PlayerMock.getMockedLocalPlayer() == player then
			PlayerMock.setMockedLocalPlayer(nil)
		end
	end)
end

return PlayerMockServiceClient
