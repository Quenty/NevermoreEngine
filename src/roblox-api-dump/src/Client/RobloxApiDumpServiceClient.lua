--!strict
--[=[
    @class RobloxApiDumpServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local Promise = require("Promise")
local Remoting = require("Remoting")
local RobloxApiDataTypes = require("RobloxApiDataTypes")
local ServiceBag = require("ServiceBag")

local RobloxApiDumpServiceClient = {}
RobloxApiDumpServiceClient.ServiceName = "RobloxApiDumpServiceClient"

export type RobloxApiDumpServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: Remoting.Remoting,
		_promiseApiDumpCache: Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>?,
	},
	{} :: typeof({ __index = RobloxApiDumpServiceClient })
))

function RobloxApiDumpServiceClient.Init(self: RobloxApiDumpServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Services
	self._serviceBag:GetService(require("RobloxApiDumpDataService"))

	-- State
	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "RobloxApiDumpServiceRemoting"))

	-- Configure
	self._maid:GiveTask(
		self._serviceBag:GetService(require("RobloxApiDumpDataService") :: any):SetPromiseApiDump(function()
			return self:_promiseApiDump()
		end)
	)
end

function RobloxApiDumpServiceClient._promiseApiDump(
	self: RobloxApiDumpServiceClient
): Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>
	if self._promiseApiDumpCache then
		return self._promiseApiDumpCache
	end

	local promise = self._remoting.GetApiDumpData:PromiseInvokeServer()
	self._promiseApiDumpCache = promise
	return promise
end

function RobloxApiDumpServiceClient.Destroy(self: RobloxApiDumpServiceClient): ()
	self._maid:DoCleaning()
end

return RobloxApiDumpServiceClient
