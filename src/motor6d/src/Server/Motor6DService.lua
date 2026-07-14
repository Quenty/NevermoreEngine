--!strict
--[=[
	@class Motor6DService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local Motor6DService = {}
Motor6DService.ServiceName = "Motor6DService"

export type Motor6DService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = Motor6DService })
))

function Motor6DService.Init(self: Motor6DService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Services
	self._serviceBag:GetService(require("TieRealmService"))

	-- Binders
	self._serviceBag:GetService(require("Motor6DStack"))
	self._serviceBag:GetService(require("Motor6DStackHumanoid"))
end

return Motor6DService
