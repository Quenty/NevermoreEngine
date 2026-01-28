--!nonstrict
--[=[
	@class RogueHumanoidClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local RogueHumanoidBase = require("RogueHumanoidBase")
local ServiceBag = require("ServiceBag")

local RogueHumanoidClient = setmetatable({}, RogueHumanoidBase)
RogueHumanoidClient.ClassName = "RogueHumanoidClient"
RogueHumanoidClient.__index = RogueHumanoidClient

function RogueHumanoidClient.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag), RogueHumanoidClient)

	return self
end

return Binder.new("RogueHumanoid", RogueHumanoidClient)
