--[=[
	Manages speed of a humanoid

	@server
	@class HumanoidSpeed
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RogueHumanoidProperties = require("RogueHumanoidProperties")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

local HumanoidSpeed = setmetatable({}, BaseObject)
HumanoidSpeed.ClassName = "HumanoidSpeed"
HumanoidSpeed.__index = HumanoidSpeed

--[=[
	Constructs a new HumanoidSpeed
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return HumanoidSpeed
]=]
function HumanoidSpeed.new(humanoid: Humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), HumanoidSpeed)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._properties = RogueHumanoidProperties:GetPropertyTable(self._serviceBag, self._obj)

	return self
end

--[=[
	Sets the default speed for the humanoid
	@param defaultSpeed number
]=]
function HumanoidSpeed:SetDefaultSpeed(defaultSpeed)
	self._properties.WalkSpeed:SetBaseValue(defaultSpeed)
end

--[=[
	Applies a speed multipler to the player's speed
	@param multiplier number
	@return function -- Cleanup function
]=]
function HumanoidSpeed:ApplySpeedMultiplier(multiplier: number)
	assert(type(multiplier) == "number", "Bad multiplier")
	assert(multiplier >= 0, "Bad multiplier")

	return self._properties.WalkSpeed:CreateMultiplier(multiplier)
end

--[=[
	Applies a speed additive to the player's speed
	@param amount number
	@return function -- Cleanup function
]=]
function HumanoidSpeed:ApplySpeedAdditive(amount: number)
	assert(type(amount) == "number", "Bad amount")

	return self._properties.WalkSpeed:CreateAdditive(amount)
end

return PlayerHumanoidBinder.new("HumanoidSpeed", HumanoidSpeed)