--!strict
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

export type RogueHumanoidClient = typeof(setmetatable(
	{} :: {},
	{} :: typeof({ __index = RogueHumanoidClient })
)) & RogueHumanoidBase.RogueHumanoidBase

function RogueHumanoidClient.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): RogueHumanoidClient
	local self: RogueHumanoidClient = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag) :: any, RogueHumanoidClient)

	self._maid:GiveTask((RogueHumanoidInterface :: any).Client:Implement(self._obj, self))

	return self
end

return Binder.new("RogueHumanoid", RogueHumanoidClient :: any) :: Binder.Binder<RogueHumanoidClient>
