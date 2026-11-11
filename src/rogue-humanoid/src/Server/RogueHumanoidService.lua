--!strict
--[=[
	@class RogueHumanoidService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local RogueHumanoidService = {}
RogueHumanoidService.ServiceName = "RogueHumanoidService"

export type RogueHumanoidService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = RogueHumanoidService })
))

function RogueHumanoidService.Init(self: RogueHumanoidService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RoguePropertyService"))

	-- Internal
	self._serviceBag:GetService(require("RogueHumanoid"))
end

return RogueHumanoidService
