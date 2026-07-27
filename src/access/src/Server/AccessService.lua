--!strict
--[=[
	Server entry point for the access package. Brings up the shared [AccessDataService] and the
	server-only pieces built on it, so a game starts access with one `GetService` instead of knowing
	which half of it lives where.

	```lua
	serviceBag:GetService(require("AccessService"))
	```

	Facts and features are still registered in shared code -- both realms have to agree on what exists,
	and a registration only the server ran is a fact the client can never resolve. This service exists to
	own the things that genuinely are server-only: overriding a fact, and replicating the result.

	@server
	@class AccessService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local AccessCommandService = require("AccessCommandService")
local AccessDataService = require("AccessDataService")
local AccessPlayer = require("AccessPlayer")
local AccessPolicyService = require("AccessPolicyService")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local AccessService = {}
AccessService.ServiceName = "AccessService"

export type AccessService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_accessDataService: AccessDataService.AccessDataService,
		_accessPolicyService: AccessPolicyService.AccessPolicyService,
	},
	{} :: typeof({ __index = AccessService })
))

function AccessService.Init(self: AccessService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService) :: any
	self._serviceBag:GetService(AccessCommandService)
	self._serviceBag:GetService(AccessPlayer)
end

function AccessService.Start(self: AccessService): ()
	-- The real leave signal lives here rather than in the shared service, which must not reach for a
	-- player-observing package: those all depend on playermock, and a second path to it duplicates the
	-- module in a built place.
	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player: Player)
		self._accessPolicyService:AddPlayer(player)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self._accessPolicyService:RemovePlayer(player)
		self._accessDataService:TeardownPlayer(player)
	end))

	for _, player in Players:GetPlayers() do
		self._accessPolicyService:AddPlayer(player)
	end

	self._maid:GiveTask(function()
		for _, player in Players:GetPlayers() do
			self._accessPolicyService:RemovePlayer(player)
		end
	end)
end

--[=[
	The policy registry, for a game registering or enabling its own consequences.

	@return AccessPolicyService
]=]
function AccessService.GetAccessPolicyService(self: AccessService): AccessPolicyService.AccessPolicyService
	return self._accessPolicyService
end

--[=[
	The shared registry, for a game registering its facts and features.

	@return AccessDataService
]=]
function AccessService.GetAccessDataService(self: AccessService): AccessDataService.AccessDataService
	return self._accessDataService
end

function AccessService.Destroy(self: AccessService): ()
	self._maid:DoCleaning()
end

return AccessService
