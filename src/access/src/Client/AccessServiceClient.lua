--!strict
--[=[
	Client entry point for the access package. The mirror of [AccessService]: brings up the shared
	[AccessDataService] plus whatever is client-only, so a game starts access the same way in both realms.

	```lua
	serviceBag:GetService(require("AccessServiceClient"))
	```

	The client resolves its own facts rather than being told the verdict, which is what keeps a menu from
	rendering nothing while it waits on the server. Facts the client genuinely cannot resolve are the
	exception, and those replicate.

	@client
	@class AccessServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local AccessCommandServiceClient = require("AccessCommandServiceClient")
local AccessDataService = require("AccessDataService")
local AccessPlayerClient = require("AccessPlayerClient")
local AccessPolicyService = require("AccessPolicyService")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local AccessServiceClient = {}
AccessServiceClient.ServiceName = "AccessServiceClient"

export type AccessServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_accessDataService: AccessDataService.AccessDataService,
		_accessPolicyService: AccessPolicyService.AccessPolicyService,
	},
	{} :: typeof({ __index = AccessServiceClient })
))

function AccessServiceClient.Init(self: AccessServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService) :: any
	self._serviceBag:GetService(AccessCommandServiceClient)
	self._serviceBag:GetService(AccessPlayerClient)
end

--[[
	The client half of what [AccessService] does on join: without this a client-realm policy is registered,
	enabled, listed by `access-policies` -- and never applied to anybody, because a policy only runs against
	a player somebody added.

	The local player and nobody else. Player instances replicate, so this realm can answer questions about
	everyone here, but a client-realm consequence is presentation *for the person at this client* -- adding
	the rest would raise this client's paywall on a stranger's verdict.

	Read once, matching production: `Players.LocalPlayer` exists before any LocalScript runs, and a headless
	test designates its [PlayerMock] before booting bags for the same reason. A realm with neither simply
	runs no client policies, which is what a bag with no client to speak for should do.
]]
function AccessServiceClient.Start(self: AccessServiceClient): ()
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer then
		self._maid:GiveTask(self._accessPolicyService:AddPlayer(localPlayer))
	end
end

--[=[
	The shared registry, for a game registering its facts and features.

	@return AccessDataService
]=]
function AccessServiceClient.GetAccessDataService(self: AccessServiceClient): AccessDataService.AccessDataService
	return self._accessDataService
end

--[=[
	The policy registry, for naming policies client-side.

	@return AccessPolicyService
]=]
function AccessServiceClient.GetAccessPolicyService(self: AccessServiceClient): AccessPolicyService.AccessPolicyService
	return self._accessPolicyService
end

function AccessServiceClient.Destroy(self: AccessServiceClient): ()
	self._maid:DoCleaning()
end

return AccessServiceClient
