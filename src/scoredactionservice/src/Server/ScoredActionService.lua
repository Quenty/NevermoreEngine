--[=[
	@class ScoredActionService
]=]

local require = require(script.Parent.loader).load(script)

local ScoredActionService = {}
ScoredActionService.ServiceName = "ScoredActionService"

function ScoredActionService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("InputKeyMapService"))
end

return ScoredActionService