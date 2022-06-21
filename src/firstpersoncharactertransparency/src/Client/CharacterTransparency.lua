---
-- @classmod CharacterTransparency
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local ModelTransparencyEffect = require("ModelTransparencyEffect")
local DisableHatParticles = require("DisableHatParticles")

local CharacterTransparency = setmetatable({}, BaseObject)
CharacterTransparency.ClassName = "CharacterTransparency"
CharacterTransparency.__index = CharacterTransparency

function CharacterTransparency.new(serviceBag, character, tweener)
	local self = setmetatable(BaseObject.new(character), CharacterTransparency)

	self._character = assert(character, "Bad character")
	self._tweener = assert(tweener, "Bad tweener")

	self._modelTransparency = ModelTransparencyEffect.new(serviceBag, self._character)
	self._modelTransparency:SetAcceleration(40)
	self._maid:GiveTask(self._modelTransparency)

	self._enabled = Instance.new("BoolValue")
	self._enabled.Value = false
	self._maid:GiveTask(self._enabled)

	self._maid:GiveTask(self._enabled.Changed:Connect(function()
		self:_onEnabledChanged()
	end))

	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		self:_update()
	end))

	self:_update()

	return self
end

function CharacterTransparency:_update()
	self._enabled.Value = self:_getShouldBeVisible()
end

function CharacterTransparency:_getShouldBeVisible()
	if self._tweener:GetPercentVisible() <= 0.5 then
		return false
	end

	-- hope this isn't slow
	local desiredPosition = self._tweener:GetCameraEffect().CameraState.CFrame.p
	local position = workspace.CurrentCamera.CFrame.p
	return (position - desiredPosition).magnitude <= 2
end

function CharacterTransparency:_onEnabledChanged()
	if self._enabled.Value then
		if not self._maid._disableHatParticles then
			self._maid._disableHatParticles = DisableHatParticles.new(self._character)
		end

		self._modelTransparency:SetTransparency(1)
	else
		self._modelTransparency:SetTransparency(0)
		self._maid._disableHatParticles = nil
	end
end

return CharacterTransparency