--[=[
	@class FakeSkyboxService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local FakeSkyboxService = {}
FakeSkyboxService.ServiceName = "FakeSkyboxService"

function FakeSkyboxService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return FakeSkyboxService