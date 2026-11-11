--!strict
--[=[
	@class IdleService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local IdleService = {}
IdleService.ServiceName = "IdleService"

export type IdleService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = IdleService })
))

function IdleService.Init(self: IdleService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("RagdollService"))
	self._serviceBag:GetService(require("HumanoidTrackerService"))
end

return IdleService
