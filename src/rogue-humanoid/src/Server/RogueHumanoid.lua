--!strict
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

export type RogueHumanoid = typeof(setmetatable(
	{} :: {},
	{} :: typeof({ __index = RogueHumanoid })
)) & RogueHumanoidBase.RogueHumanoidBase

function RogueHumanoid.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RogueHumanoid
	local self: RogueHumanoid = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag) :: any, RogueHumanoid)

	self._maid:GiveTask(RogueHumanoidInterface.Server:Implement(self._obj, self))

	return self
end

return PlayerHumanoidBinder.new("RogueHumanoid", RogueHumanoid :: any) :: PlayerHumanoidBinder.PlayerHumanoidBinder<RogueHumanoid>
