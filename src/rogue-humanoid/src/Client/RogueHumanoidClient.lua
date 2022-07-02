--[=[
	@class RogueHumanoidClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RogueHumanoidProperties = require("RogueHumanoidProperties")

local RogueHumanoidClient = setmetatable({}, BaseObject)
RogueHumanoidClient.ClassName = "RogueHumanoidClient"
RogueHumanoidClient.__index = RogueHumanoidClient

function RogueHumanoidClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RogueHumanoidClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._properties = RogueHumanoidProperties:GetPropertyTable(self._serviceBag, self._obj)

	return self
end

return RogueHumanoidClient