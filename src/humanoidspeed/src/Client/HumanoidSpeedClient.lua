--[=[
	Client version of the [HumanoidSpeed] class

	@client
	@class HumanoidSpeedClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local Binder = require("Binder")

local HumanoidSpeedClient = setmetatable({}, BaseObject)
HumanoidSpeedClient.ClassName = "HumanoidSpeedClient"
HumanoidSpeedClient.__index = HumanoidSpeedClient

function HumanoidSpeedClient.new(humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(humanoid), HumanoidSpeedClient)

	return self
end

--[=[
	Gets the player for this humanoid
	@return Player?
]=]
function HumanoidSpeedClient:GetPlayer(): Player?
	return CharacterUtils.getPlayerFromCharacter(self._obj)
end

return Binder.new("HumanoidSpeed", HumanoidSpeedClient)
