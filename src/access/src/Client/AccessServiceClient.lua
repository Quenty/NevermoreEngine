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

local AccessCommandServiceClient = require("AccessCommandServiceClient")
local AccessDataService = require("AccessDataService")
local AccessPlayerClient = require("AccessPlayerClient")
local AccessPolicyService = require("AccessPolicyService")
local Maid = require("Maid")
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
	-- Registered here purely so the console knows every policy name. Server-realm policies never run
	-- client-side; the service skips them.
	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService) :: any
	self._serviceBag:GetService(AccessCommandServiceClient)
	self._serviceBag:GetService(AccessPlayerClient)
end

function AccessServiceClient.Start(_self: AccessServiceClient): () end

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
