--[=[
	@class UnitTestService
]=]

local require = require(script.Parent.loader).load(script)

local UnitTestService = {}
UnitTestService.ServiceName = "UnitTestService"

function UnitTestService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("UnitTestTranslator"))
end

return UnitTestService