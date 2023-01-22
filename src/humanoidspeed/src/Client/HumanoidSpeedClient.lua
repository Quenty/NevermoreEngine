--[=[
	Client version of the [HumanoidSpeed] class

	@client
	@class HumanoidSpeedClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")

local HumanoidSpeedClient = setmetatable({}, BaseObject)
HumanoidSpeedClient.ClassName = "HumanoidSpeedClient"
HumanoidSpeedClient.__index = HumanoidSpeedClient

function HumanoidSpeedClient.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), HumanoidSpeedClient)

	return self
end

--[=[
	Gets the player for this humanoid
	@return Player?
]=]
function HumanoidSpeedClient:GetPlayer()
	return CharacterUtils.getPlayerFromCharacter(self._obj)
end

return HumanoidSpeedClient