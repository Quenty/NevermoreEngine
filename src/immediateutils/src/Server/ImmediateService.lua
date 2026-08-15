--!strict
--[=[
	@class ImmediateLoopService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local ImmediateService = {}
ImmediateService.ServiceName = "ImmediateService"

export type ImmediateService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = ImmediateService })
))

function ImmediateService.Init(self: ImmediateService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return ImmediateService
