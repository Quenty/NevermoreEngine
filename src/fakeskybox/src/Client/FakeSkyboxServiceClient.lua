--[=[
	@class FakeSkyboxServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local FakeSkyboxServiceClient = {}
FakeSkyboxServiceClient.ServiceName = "FakeSkyboxServiceClient"

function FakeSkyboxServiceClient:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return FakeSkyboxServiceClient
