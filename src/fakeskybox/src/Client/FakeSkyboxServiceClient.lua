--!strict
--[=[
	@class FakeSkyboxServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local FakeSkyboxServiceClient = {}
FakeSkyboxServiceClient.ServiceName = "FakeSkyboxServiceClient"

export type FakeSkyboxServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = FakeSkyboxServiceClient })
))

function FakeSkyboxServiceClient.Init(self: FakeSkyboxServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return FakeSkyboxServiceClient
