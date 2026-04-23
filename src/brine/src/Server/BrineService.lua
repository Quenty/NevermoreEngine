--[=[
	@class BrineService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local BrineService = {}
BrineService.ServiceName = "BrineService"

function BrineService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return BrineService
