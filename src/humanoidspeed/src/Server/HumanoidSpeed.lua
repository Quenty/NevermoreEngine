--[=[
	Manages speed of a humanoid

	@server
	@class HumanoidSpeed
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local HumanoidSpeedConstants = require("HumanoidSpeedConstants")

local HumanoidSpeed = setmetatable({}, BaseObject)
HumanoidSpeed.ClassName = "HumanoidSpeed"
HumanoidSpeed.__index = HumanoidSpeed

--[=[
	Constructs a new HumanoidSpeed
	@param humanoid Humanoid
	@return HumanoidSpeed
]=]
function HumanoidSpeed.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), HumanoidSpeed)

	self._defaultSpeed = self._obj.WalkSpeed

	self._speedValue = Instance.new("IntValue")
	self._speedValue.Name = HumanoidSpeedConstants.SPEED_VALUE_NAME
	self._speedValue.Value = humanoid.WalkSpeed
	self._speedValue.Parent = humanoid

	self._multipliers = {} -- Multiplicitive, [key] = mult, takes product of this list
	self._adders = {} -- [key] = added

	self._maid:GiveTask(self._speedValue.Changed:Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

--[=[
	Sets the default speed for the humanoid
	@param defaultSpeed number
]=]
function HumanoidSpeed:SetDefaultSpeed(defaultSpeed)
	self._defaultSpeed = defaultSpeed
	self:_update()
end

--[=[
	Applies a speed multipler to the player's speed
	@param multiplier number
	@return function -- Cleanup function
]=]
function HumanoidSpeed:ApplySpeedMultiplier(multiplier)
	assert(type(multiplier) == "number", "Bad multiplier")
	assert(multiplier >= 0, "Bad multiplier")

	local key = HttpService:GenerateGUID(false)
	self._multipliers[key] = multiplier

	self:_update()

	return function()
		if self.Destroy then
			self:_removeSpeedMultiplier(key)
		end
	end
end

--[=[
	Applies a speed additive to the player's speed
	@param amount number
	@return function -- Cleanup function
]=]
function HumanoidSpeed:ApplySpeedAdditive(amount)
	assert(type(amount) == "number", "Bad amount")

	local key = HttpService:GenerateGUID(false)
	self._adders[key] = amount

	self:_update()

	return function()
		if self.Destroy then
			self:_removeSpeedAdder(key)
		end
	end
end

function HumanoidSpeed:_removeSpeedMultiplier(key)
	self._multipliers[key] = nil
	self:_update()
end


function HumanoidSpeed:_removeSpeedAdder(key)
	self._adders[key] = nil
	self:_update()
end


function HumanoidSpeed:_getMultiplier()
	local mult = 1
	for _, item in pairs(self._multipliers) do
		mult = mult * item
	end
	return mult
end

function HumanoidSpeed:_getBaseSpeed()
	local current = self._defaultSpeed
	for _, item in pairs(self._adders) do
		current = current + item
	end
	return current
end

function HumanoidSpeed:_update()
	local mult = self:_getMultiplier()
	self._speedValue.Value = mult*self:_getBaseSpeed()
	self._obj.WalkSpeed = self._speedValue.Value
end

return HumanoidSpeed