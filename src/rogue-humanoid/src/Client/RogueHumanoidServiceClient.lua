--[=[
	@class RogueHumanoidServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RogueHumanoidServiceClient = {}

function RogueHumanoidServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RoguePropertyService"))

	-- Internal
	self._serviceBag:GetService(require("RogueHumanoidBindersClient"))
end

return RogueHumanoidServiceClient