--[=[
	@class UnitTestServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local UnitTestServiceClient = {}
UnitTestServiceClient.ServiceName = "UnitTestServiceClient"

function UnitTestServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("UnitTestTranslator"))
end

return UnitTestServiceClient