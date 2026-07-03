--!nonstrict
--[=[
	@class RogueHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local RogueHumanoidBase = require("RogueHumanoidBase")
local RogueHumanoidInterface = require("RogueHumanoidInterface")
local ServiceBag = require("ServiceBag")

local RogueHumanoid = setmetatable({}, RogueHumanoidBase)
RogueHumanoid.ClassName = "RogueHumanoid"
RogueHumanoid.__index = RogueHumanoid

function RogueHumanoid.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag), RogueHumanoid)

	self._maid:GiveTask(RogueHumanoidInterface.Server:Implement(self._obj, self))

	return self
end

return PlayerHumanoidBinder.new("RogueHumanoid", RogueHumanoid)
