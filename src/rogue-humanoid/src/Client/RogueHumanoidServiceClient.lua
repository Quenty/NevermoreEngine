--!strict
--[=[
	@class RogueHumanoidServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local RogueHumanoidServiceClient = {}
RogueHumanoidServiceClient.ServiceName = "RogueHumanoidServiceClient"

export type RogueHumanoidServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = RogueHumanoidServiceClient })
))

function RogueHumanoidServiceClient.Init(self: RogueHumanoidServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RoguePropertyService"))

	-- Internal
	self._serviceBag:GetService(require("RogueHumanoidClient"))
end

return RogueHumanoidServiceClient
