--[=[
	@class IdleService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local IdleService = {}
IdleService.ServiceName = "IdleService"

function IdleService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("RagdollService"))
	self._serviceBag:GetService(require("HumanoidTrackerService"))
end

return IdleService
