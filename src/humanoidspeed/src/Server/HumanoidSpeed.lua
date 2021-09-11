--- Manages speed
-- @classmod HumanoidSpeed
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local HumanoidSpeedConstants = require("HumanoidSpeedConstants")

local HumanoidSpeed = setmetatable({}, BaseObject)
HumanoidSpeed.ClassName = "HumanoidSpeed"
HumanoidSpeed.__index = HumanoidSpeed

function HumanoidSpeed.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), HumanoidSpeed)

	self._defaultSpeed = self._obj.WalkSpeed

	self._speedValue = Instance.new("IntValue")
	self._speedValue.Name = HumanoidSpeedConstants.SPEED_VALUE_NAME
	self._speedValue.Value = humanoid.WalkSpeed
	self._speedValue.Parent = humanoid

	self._multipliers = {} -- Multiplicitive, [key] = mult, takes product of this list

	self._maid:GiveTask(self._speedValue.Changed:Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

function HumanoidSpeed:SetDefaultSpeed(defaultSpeed)
	self._defaultSpeed = defaultSpeed
	self:_update()
end

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

function HumanoidSpeed:_removeSpeedMultiplier(key)
	self._multipliers[key] = nil
	self:_update()
end

function HumanoidSpeed:_getMultiplier()
	local mult = 1
	for _, item in pairs(self._multipliers) do
		mult = mult * item
	end
	return mult
end

function HumanoidSpeed:_update()
	local mult = self:_getMultiplier()
	self._speedValue.Value = mult*self._defaultSpeed
	self._obj.WalkSpeed = self._speedValue.Value
end

return HumanoidSpeed