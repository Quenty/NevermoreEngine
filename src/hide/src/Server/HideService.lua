--!strict
--[=[
	@class HideService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local HideService = {}
HideService.ServiceName = "HideService"

function HideService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("Hide"))
end

return HideService
