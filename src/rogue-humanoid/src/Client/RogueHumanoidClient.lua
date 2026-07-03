--!nonstrict
--[=[
	@class RogueHumanoidClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local RogueHumanoidBase = require("RogueHumanoidBase")
local RogueHumanoidInterface = require("RogueHumanoidInterface")
local ServiceBag = require("ServiceBag")

local RogueHumanoidClient = setmetatable({}, RogueHumanoidBase)
RogueHumanoidClient.ClassName = "RogueHumanoidClient"
RogueHumanoidClient.__index = RogueHumanoidClient

function RogueHumanoidClient.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag), RogueHumanoidClient)

	self._maid:GiveTask(RogueHumanoidInterface.Client:Implement(self._obj, self))

	return self
end

return Binder.new("RogueHumanoid", RogueHumanoidClient)
