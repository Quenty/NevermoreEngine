--[=[
	@class SpawnServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local SpawnServiceClient = {}
SpawnServiceClient.ServiceName = "SpawnServiceClient"

function SpawnServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("CmdrServiceClient"))
end

return SpawnServiceClient