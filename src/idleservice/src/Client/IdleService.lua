--- Helps track whether or not a player is idle and if so, then can show UI or other cute things
-- @module IdleService
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local HumanoidTrackerService = require("HumanoidTrackerService")
local Maid = require("Maid")
local RagdollBindersClient = require("RagdollBindersClient")
local StateStack = require("StateStack")

local IdleService = {}

local STANDING_TIME_REQUIRED = 0.5

function IdleService:Init(serviceBag)
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._humanoidTracker = serviceBag:GetService(HumanoidTrackerService):GetHumanoidTracker()
	self._ragdollBindersClient = serviceBag:GetService(RagdollBindersClient)

	self._disabledStack = StateStack.new()
	self._maid:GiveTask(self._disabledStack)

	self._enabled = Instance.new("BoolValue")
	self._enabled.Value = true
	self._maid:GiveTask(self._enabled)

	self._showIdleUI = Instance.new("BoolValue")
	self._showIdleUI.Value = false
	self._maid:GiveTask(self._showIdleUI)

	self._humanoidIdle = Instance.new("BoolValue")
	self._humanoidIdle.Value = false
	self._maid:GiveTask(self._humanoidIdle)

	self._maid:GiveTask(self._humanoidIdle.Changed:Connect(function()
		self:_updateShowIdleUI()
	end))
	self._maid:GiveTask(self._enabled.Changed:Connect(function()
		self:_updateShowIdleUI()
	end))

	self._maid:GiveTask(self._humanoidTracker.AliveHumanoid.Changed:Connect(function(...)
		self:_handleAliveHumanoidChanged(...)
	end))
	self._maid:GiveTask(self._disabledStack.Changed:Connect(function()
		self._enabled.Value = not self._disabledStack:GetState()
	end))

	if self._humanoidTracker.AliveHumanoid.Value then
		self:_handleAliveHumanoidChanged()
	end
	self:_updateShowIdleUI()
end

function IdleService:IsHumanoidIdle()
	return self._humanoidIdle.Value
end

function IdleService:DoShowIdleUI()
	return self._showIdleUI.Value
end

function IdleService:GetShowIdleUIBoolValue()
	assert(self._showIdleUI, "Not initialized")

	return self._showIdleUI
end

function IdleService:PushDisable()
	if not RunService:IsRunning() then
		return function() end
	end

	assert(self._disabledStack, "Not initialized")
	return self._disabledStack:PushState()
end

function IdleService:_setEnabled(enabled)
	assert(type(enabled) == "boolean", "Bad enabled")
	self._enabled.Value = enabled
end

function IdleService:_updateShowIdleUI()
	self._showIdleUI.Value = self._humanoidIdle.Value and self._enabled.Value and not VRService.VREnabled
end

function IdleService:_handleAliveHumanoidChanged()
	local humanoid = self._humanoidTracker.AliveHumanoid.Value
	if not humanoid then
		self._maid._humanoidMaid = nil
		return
	end

	local maid = Maid.new()

	local lastMove = tick()

	maid:GiveTask(function()
		self._humanoidIdle.Value = false
	end)

	local function update()
		if tick() - lastMove >= STANDING_TIME_REQUIRED then
			self._humanoidIdle.Value = true
		else
			self._humanoidIdle.Value = false
		end
	end

	maid:GiveTask(self._enabled.Changed:Connect(function()
		lastMove = tick()
	end))

	maid:GiveTask(RunService.Stepped:Connect(function()
		local rootPart = humanoid.RootPart

		if self._ragdollBindersClient.Ragdoll:Get(humanoid) then
			lastMove = tick()
		elseif rootPart then
			if rootPart.Velocity.magnitude > 2.5 then
				lastMove = tick()
			end
		end

		update()
	end))

	self._maid._humanoidMaid = maid
end

return IdleService