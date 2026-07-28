--!strict
--[=[
	Registers the access argument types on the client, so the console autocompletes fact and feature names
	as you type them. The commands themselves are server-side in [AccessCommandService]; this only teaches
	the client what the arguments look like.

	@client
	@class AccessCommandServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local AccessCommandUtils = require("AccessCommandUtils")
local AccessDataService = require("AccessDataService")
local AccessPolicyService = require("AccessPolicyService")
local CmdrServiceClient = require("CmdrServiceClient")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local AccessCommandServiceClient = {}
AccessCommandServiceClient.ServiceName = "AccessCommandServiceClient"

export type AccessCommandServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrServiceClient: any,
		_accessDataService: AccessDataService.AccessDataService,
		_accessPolicyService: AccessPolicyService.AccessPolicyService,
	},
	{} :: typeof({ __index = AccessCommandServiceClient })
))

function AccessCommandServiceClient.Init(self: AccessCommandServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrServiceClient = self._serviceBag:GetService(CmdrServiceClient)

	-- Internal
	self._accessDataService = self._serviceBag:GetService(AccessDataService) :: any
	self._accessPolicyService = self._serviceBag:GetService(AccessPolicyService) :: any
end

function AccessCommandServiceClient.Start(self: AccessCommandServiceClient): ()
	self._maid:GivePromise(self._cmdrServiceClient:PromiseCmdr()):Then(function(cmdr)
		-- Autocomplete comes off the client's own registry, which is the point of registering facts in
		-- shared code: the names the console offers are the names the server will recognize.
		AccessCommandUtils.registerTypes(cmdr, self._accessDataService, function()
			return self._accessPolicyService:GetPolicyNames()
		end)
	end)
end

function AccessCommandServiceClient.Destroy(self: AccessCommandServiceClient): ()
	self._maid:DoCleaning()
end

return AccessCommandServiceClient
