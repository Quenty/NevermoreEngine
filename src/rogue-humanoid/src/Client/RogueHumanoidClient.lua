--[=[
	@class RogueHumanoidClient
]=]

local require = require(script.Parent.loader).load(script)

local RogueHumanoidBase = require("RogueHumanoidBase")
local Binder = require("Binder")

local RogueHumanoidClient = setmetatable({}, RogueHumanoidBase)
RogueHumanoidClient.ClassName = "RogueHumanoidClient"
RogueHumanoidClient.__index = RogueHumanoidClient

function RogueHumanoidClient.new(humanoid, serviceBag)
	local self = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag), RogueHumanoidClient)

	return self
end

return Binder.new("RogueHumanoid", RogueHumanoidClient)