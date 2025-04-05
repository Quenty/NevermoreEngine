--[=[
	@class RogueHumanoidService
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local RogueHumanoidService = {}
RogueHumanoidService.ServiceName = "RogueHumanoidService"

function RogueHumanoidService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RoguePropertyService"))

	-- Internal
	self._serviceBag:GetService(require("RogueHumanoid"))
end

return RogueHumanoidService