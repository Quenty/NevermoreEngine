--[=[
	@class BrineServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local BrineServiceClient = {}
BrineServiceClient.ServiceName = "BrineServiceClient"

function BrineServiceClient:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return BrineServiceClient
