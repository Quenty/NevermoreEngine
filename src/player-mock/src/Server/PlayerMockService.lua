--!strict
--[=[
	Server-side home for the [PlayerMock]s a test stands up, and the discovery surface PlayerBinders
	observe. Creating a mock through the service (rather than `PlayerMock.new` by hand) parents it into
	the world and ties its lifetime to the service maid -- so tearing down the ServiceBag cleans up every
	mock it made.

	Replication is the default, mirroring how a real `Player` exists for every peer: any mock parented
	into the DataModel (this service's or a hand-built one) is discovered by every [PlayerMockService]
	and [PlayerMockServiceClient] in the place, across ServiceBags and realms -- which is what lets
	TieInterfaces and Remoting bridge a server bag and a client bag in the same test.

	Discovery and leak detection live in [PlayerMockServiceBase]: mocks may exist *before* this
	service boots (create and designate first, then boot -- production parity), and a leak is a mock
	that outlived the service that consumed it, not a mock that predates boot. There is one server per
	place, so only one server-realm service may be alive at a time.

	```lua
	local playerMockService = serviceBag:GetService(require("PlayerMockService"))
	local player = playerMockService:CreatePlayer({ UserId = 12345 })
	```

	@class PlayerMockService
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local PlayerMock = require("PlayerMock")
local PlayerMockServiceBase = require("PlayerMockServiceBase")

local PlayerMockService = setmetatable({}, { __index = PlayerMockServiceBase })
PlayerMockService.ServiceName = "PlayerMockService"
PlayerMockService._consumedAttributeName = "PlayerMockConsumedServer"
PlayerMockService._allowConcurrentConsumers = false

--[=[
	Creates a [PlayerMock], parents it into the world -- which replicates it, so PlayerBinders and
	[PlayerMockServiceClient]s in every bag discover it like a real join -- and tracks it for cleanup.

	@param overrides { [string]: any }? -- Per-property seed values, e.g. `{ UserId = 12345 }` (see [PlayerMock.new]).
	@return Player
]=]
function PlayerMockService:CreatePlayer(overrides: { [string]: any }?): Player
	local player = PlayerMock.new(overrides)
	player.Parent = Workspace

	self._maid:GiveTask(player)

	return player
end

return PlayerMockService
