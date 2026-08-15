--!strict
--[=[
	@client
	@class ImmediateLoopServiceClient

	Maintains a single loop for immediate-mode ECS systems.
	There is exactly one world and one loop per running client or server.
	All added systems will be run synchronously and non-yielding inside RunService events.
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local ImmediateServiceClient = {}
ImmediateServiceClient.ServiceName = "ImmediateServiceClient"

export type ImmediateServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = ImmediateServiceClient })
))

function ImmediateServiceClient.Init(self: ImmediateServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return ImmediateServiceClient
