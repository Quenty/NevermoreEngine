--!strict
--[=[
	@class InputKeyMapService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local InputKeyMapService = {}
InputKeyMapService.ServiceName = "InputKeyMapService"

export type InputKeyMapService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = InputKeyMapService })
))

function InputKeyMapService.Init(self: InputKeyMapService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))
	self._serviceBag:GetService(require("InputKeyMapTranslator"))
end

return InputKeyMapService
