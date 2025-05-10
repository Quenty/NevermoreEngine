--[=[
	@class Motor6DService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local Motor6DService = {}
Motor6DService.ServiceName = "Motor6DService"

function Motor6DService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Services
	self._serviceBag:GetService(require("TieRealmService"))

	-- Binders
	self._serviceBag:GetService(require("Motor6DStack"))
	self._serviceBag:GetService(require("Motor6DStackHumanoid"))
end

return Motor6DService
