--[=[
	@class InputKeyMapService
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local InputKeyMapService = {}
InputKeyMapService.ServiceName = "InputKeyMapService"

function InputKeyMapService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))
	self._serviceBag:GetService(require("InputKeyMapTranslator"))
end

return InputKeyMapService