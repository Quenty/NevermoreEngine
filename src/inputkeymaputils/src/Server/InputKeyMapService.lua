--[=[
	@class InputKeyMapService
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapService = {}
InputKeyMapService.ServiceName = "InputKeyMapService"

function InputKeyMapService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))
end

return InputKeyMapService