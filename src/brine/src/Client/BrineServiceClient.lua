--!strict
--[=[
	@class BrineServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local BrineServiceClient = {}
BrineServiceClient.ServiceName = "BrineServiceClient"

export type BrineServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = BrineServiceClient })
))

function BrineServiceClient.Init(self: BrineServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return BrineServiceClient
