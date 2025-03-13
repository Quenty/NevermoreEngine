--[=[
	Helps track whether or not a player is idle and if so, then can show UI or other cute things.

	@client
	@class IdleServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local Maid = require("Maid")
local RagdollClient = require("RagdollClient")
local Rx = require("Rx")
local StateStack = require("StateStack")
local ValueObject = require("ValueObject")
local _ServiceBag = require("ServiceBag")

local IdleServiceClient = {}
IdleServiceClient.ServiceName = "IdleServiceClient"

local STANDING_TIME_REQUIRED = 0.5
local MOVE_DISTANCE_REQUIRED = 2.5

--[=[
	Initializes the idle service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function IdleServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("RagdollServiceClient"))
	self._serviceBag:GetService(require("HumanoidTrackerService"))

	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	-- Configure
	self._disableStack = self._maid:Add(StateStack.new(false, "boolean"))
	self._enabled = self._maid:Add(ValueObject.new(true, "boolean"))
	self._showIdleUI = self._maid:Add(ValueObject.new(false, "boolean"))
	self._humanoidIdle = self._maid:Add(ValueObject.new(false, "boolean"))
	self._lastPosition = self._maid:Add(ValueObject.new(nil))
end

--[=[
	Starts idle service on the client. Should be done via [ServiceBag].
]=]
function IdleServiceClient:Start()
	self._maid:GiveTask(self._humanoidIdle.Changed:Connect(function()
		self:_updateShowIdleUI()
	end))
	self._maid:GiveTask(self._enabled.Changed:Connect(function()
		self:_updateShowIdleUI()
	end))

	self._humanoidTracker = self._serviceBag:GetService(require("HumanoidTrackerService")):GetHumanoidTracker()
	if self._humanoidTracker then
		self._maid:GiveTask(self._humanoidTracker.AliveHumanoid.Changed:Connect(function(...)
			self:_handleAliveHumanoidChanged(...)
		end))
		self._maid:GiveTask(self._disableStack.Changed:Connect(function()
			self._enabled.Value = not self._disableStack:GetState()
		end))

		if self._humanoidTracker.AliveHumanoid.Value then
			self:_handleAliveHumanoidChanged()
		end
	end

	self:_updateShowIdleUI()
end

--[=[
	Observes a humanoid moving from the current position after a set amount of time. Can be used
	to close a UI when the humanoid wanders too far.

	@return Observable
]=]
function IdleServiceClient:ObserveHumanoidMoveFromCurrentPosition(minimumTimeVisible: number)
	assert(type(minimumTimeVisible) == "number", "Bad minimumTimeVisible")

	return Rx.of(true):Pipe({
		Rx.delay(minimumTimeVisible);
		Rx.flatMap(function()
			return self._lastPosition:Observe()
		end);
		Rx.where(function(value)
			return value ~= nil
		end);
		Rx.first();
		Rx.flatMap(function(initialPosition)
			return self._lastPosition:Observe():Pipe({
				Rx.where(function(position)
					return position == nil or (initialPosition - position).magnitude >= MOVE_DISTANCE_REQUIRED
				end)
			})
		end);
		Rx.first();
	})
end

--[=[
	Returns whether the humanoid is idle.
	@return boolean
]=]
function IdleServiceClient:IsHumanoidIdle(): boolean
	return self._humanoidIdle.Value
end

--[=[
	Returns whether the humanoid is idle.
	@return boolean
]=]
function IdleServiceClient:IsMoving(): boolean
	return not self._humanoidIdle.Value
end

--[=[
	observes if the humanoid is idle.
	@return Observable<boolean>
]=]
function IdleServiceClient:ObserveHumanoidIdle()
	return self._humanoidIdle:Observe()
end

--[=[
	Returns whether UI should be shown (if the humanoid is idle)
	@return boolean
]=]
function IdleServiceClient:DoShowIdleUI()
	return self._showIdleUI.Value
end

--[=[
	Observes whether to show the the idle UI
	@return Observable<boolean>
]=]
function IdleServiceClient:ObserveShowIdleUI()
	return self._showIdleUI:Observe()
end

--[=[
	Returns a show idle bool value.
	@return BoolValue
]=]
function IdleServiceClient:GetShowIdleUIBoolValue()
	assert(self._showIdleUI, "Not initialized")

	return self._showIdleUI
end

--[=[
	Pushes a disabling function that disables idle UI
	@return boolean
]=]
function IdleServiceClient:PushDisable()
	if not RunService:IsRunning() then
		return function() end
	end

	assert(self._disableStack, "Not initialized")
	return self._disableStack:PushState(true)
end

function IdleServiceClient:_setEnabled(enabled: boolean)
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

	local lastMove = os.clock()

	maid:GiveTask(function()
		self._lastPosition.Value = nil
		self._humanoidIdle.Value = false
	end)

	local function update()
		if os.clock() - lastMove >= STANDING_TIME_REQUIRED then
			self._humanoidIdle.Value = true
		else
			self._humanoidIdle.Value = false
		end
	end

	maid:GiveTask(self._enabled.Changed:Connect(function()
		lastMove = os.clock()
	end))

	maid:GiveTask(RunService.Stepped:Connect(function()
		local rootPart = humanoid.RootPart

		if rootPart then
			self._lastPosition.Value = rootPart.Position
		end

		if self._ragdollBinder:Get(humanoid) then
			lastMove = os.clock()
		elseif rootPart then
			if rootPart.Velocity.magnitude > MOVE_DISTANCE_REQUIRED then
				lastMove = os.clock()
			end
		end

		update()
	end))

	self._maid._humanoidMaid = maid
end

function IdleServiceClient:Destroy()
	self._maid:DoCleaning()
end

return IdleServiceClient