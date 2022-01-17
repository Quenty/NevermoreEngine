--[=[
	Helps track whether or not a player is idle and if so, then can show UI or other cute things
	@class IdleServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local HumanoidTrackerService = require("HumanoidTrackerService")
local Maid = require("Maid")
local RagdollBindersClient = require("RagdollBindersClient")
local StateStack = require("StateStack")
local RxValueBaseUtils = require("RxValueBaseUtils")

local IdleServiceClient = {}

local STANDING_TIME_REQUIRED = 0.5

function IdleServiceClient:Init(serviceBag)
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RagdollServiceClient"))
	self._humanoidTracker = self._serviceBag:GetService(HumanoidTrackerService):GetHumanoidTracker()
	self._ragdollBindersClient = self._serviceBag:GetService(RagdollBindersClient)

	self._disabledStack = StateStack.new(false)
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
end

function IdleServiceClient:Start()
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

function IdleServiceClient:IsHumanoidIdle()
	return self._humanoidIdle.Value
end

function IdleServiceClient:DoShowIdleUI()
	return self._showIdleUI.Value
end

function IdleServiceClient:ObserveShowIdleUI()
	return RxValueBaseUtils.observeValue(self._showIdleUI)
end

function IdleServiceClient:GetShowIdleUIBoolValue()
	assert(self._showIdleUI, "Not initialized")

	return self._showIdleUI
end

function IdleServiceClient:PushDisable()
	if not RunService:IsRunning() then
		return function() end
	end

	assert(self._disabledStack, "Not initialized")
	return self._disabledStack:PushState(true)
end

function IdleServiceClient:_setEnabled(enabled)
	assert(type(enabled) == "boolean", "Bad enabled")
	self._enabled.Value = enabled
end

function IdleServiceClient:_updateShowIdleUI()
	self._showIdleUI.Value = self._humanoidIdle.Value and self._enabled.Value and not VRService.VREnabled
end

function IdleServiceClient:_handleAliveHumanoidChanged()
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

return IdleServiceClient