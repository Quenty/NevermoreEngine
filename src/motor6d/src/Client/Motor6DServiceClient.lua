--[=[
	@class Motor6DServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local Motor6DServiceClient = {}
Motor6DServiceClient.ServiceName = "Motor6DServiceClient"

function Motor6DServiceClient:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Services
	self._serviceBag:GetService(require("TieRealmService"))

	-- Binders
	self._serviceBag:GetService(require("Motor6DStackClient"))
end

return Motor6DServiceClient
