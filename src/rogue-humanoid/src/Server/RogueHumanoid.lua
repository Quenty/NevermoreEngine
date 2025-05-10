--[=[
	@class RogueHumanoid
]=]

local require = require(script.Parent.loader).load(script)

local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local RogueHumanoidBase = require("RogueHumanoidBase")

local RogueHumanoid = setmetatable({}, RogueHumanoidBase)
RogueHumanoid.ClassName = "RogueHumanoid"
RogueHumanoid.__index = RogueHumanoid

function RogueHumanoid.new(humanoid, serviceBag)
	local self = setmetatable(RogueHumanoidBase.new(humanoid, serviceBag), RogueHumanoid)

	return self
end

return PlayerHumanoidBinder.new("RogueHumanoid", RogueHumanoid)
