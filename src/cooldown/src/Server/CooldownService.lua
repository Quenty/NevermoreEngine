--!strict
--[=[
	@class CooldownService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local CooldownService = {}
CooldownService.ServiceName = "CooldownService"

function CooldownService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))

	-- Internal
	self._serviceBag:GetService(require("Cooldown"))
	self._serviceBag:GetService(require("CooldownShared"))
end

return CooldownService
