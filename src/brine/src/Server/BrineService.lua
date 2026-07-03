--!strict
--[=[
	@class BrineService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local BrineService = {}
BrineService.ServiceName = "BrineService"

export type BrineService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = BrineService })
))

function BrineService.Init(self: BrineService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return BrineService
