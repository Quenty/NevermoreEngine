--!strict
--[=[
	Client version of the [HumanoidSpeed] class

	@client
	@class HumanoidSpeedClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local CharacterUtils = require("CharacterUtils")

local HumanoidSpeedClient = setmetatable({}, BaseObject)
HumanoidSpeedClient.ClassName = "HumanoidSpeedClient"
HumanoidSpeedClient.__index = HumanoidSpeedClient

export type HumanoidSpeedClient = typeof(setmetatable(
	{} :: {},
	{} :: typeof({ __index = HumanoidSpeedClient })
)) & BaseObject.BaseObject

function HumanoidSpeedClient.new(humanoid: Humanoid): HumanoidSpeedClient
	local self: HumanoidSpeedClient = setmetatable(BaseObject.new(humanoid) :: any, HumanoidSpeedClient)

	return self
end

--[=[
	Gets the player for this humanoid
	@return Player?
]=]
function HumanoidSpeedClient.GetPlayer(self: HumanoidSpeedClient): Player?
	return CharacterUtils.getPlayerFromCharacter(self._obj :: Instance)
end

return Binder.new("HumanoidSpeed", HumanoidSpeedClient :: any) :: Binder.Binder<HumanoidSpeedClient>
