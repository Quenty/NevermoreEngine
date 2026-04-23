--!strict
--[=[
    @class RobloxApiDumpService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local Promise = require("Promise")
local PromiseRetryUtils = require("PromiseRetryUtils")
local Remoting = require("Remoting")
local RobloxApiDataTypes = require("RobloxApiDataTypes")
local RobloxApiUtils = require("RobloxApiUtils")
local ServiceBag = require("ServiceBag")

local RobloxApiDumpService = {}
RobloxApiDumpService.ServiceName = "RobloxApiDumpService"

export type RobloxApiDumpService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_remoting: Remoting.Remoting,
		_maid: Maid.Maid,
		_promiseApiDumpCache: Promise.Promise<any>?,
	},
	{} :: typeof({ __index = RobloxApiDumpService })
))

function RobloxApiDumpService.Init(self: RobloxApiDumpService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Services
	self._serviceBag:GetService(require("RobloxApiDumpDataService"))

	-- Configure
	self._serviceBag:GetService(require("RobloxApiDumpDataService") :: any):SetPromiseApiDump(function()
		return self:_promiseRobloxApiDumpData()
	end)
end

function RobloxApiDumpService.Start(self: RobloxApiDumpService): ()
	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "RobloxApiDumpServiceRemoting"))
	self._maid:GiveTask(self._remoting.GetApiDumpData:Bind(function()
		return self:_promiseRobloxApiDumpData()
	end))
end

function RobloxApiDumpService._promiseRobloxApiDumpData(
	self: RobloxApiDumpService
): Promise.Promise<RobloxApiDataTypes.RobloxApiDumpData>
	if self._promiseApiDumpCache then
		return self._promiseApiDumpCache
	end

	local promise = PromiseRetryUtils.retry(function()
		return RobloxApiUtils.promiseDump()
	end, {
		maxAttempts = 10,
		initialWaitTime = 10,
		printWarning = true,
	})

	self._promiseApiDumpCache = promise
	return promise
end

function RobloxApiDumpService.Destroy(self: RobloxApiDumpService): ()
	self._maid:DoCleaning()
end

return RobloxApiDumpService
