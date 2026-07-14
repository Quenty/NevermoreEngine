--!strict
--[=[
	@class FakeSkyboxService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local FakeSkyboxService = {}
FakeSkyboxService.ServiceName = "FakeSkyboxService"

export type FakeSkyboxService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = FakeSkyboxService })
))

function FakeSkyboxService.Init(self: FakeSkyboxService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
end

return FakeSkyboxService
