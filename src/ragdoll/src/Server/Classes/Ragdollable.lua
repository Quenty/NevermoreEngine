--[=[
	Should be bound to any humanoid that is ragdollable. See [RagdollBindersServer].
	@server
	@class Ragdollable
]=]

local require = require(script.Parent.loader).load(script)

-- local AttributeUtils = require("AttributeUtils")
local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")
local Maid = require("Maid")
local RagdollableConstants = require("RagdollableConstants")
local RagdollBindersServer = require("RagdollBindersServer")
local RagdollRigging = require("RagdollRigging")
local RagdollUtils = require("RagdollUtils")

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

--[=[
	Constructs a new Ragdollable. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return Ragdollable
]=]
function Ragdollable.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), Ragdollable)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersServer).Ragdoll

	self._obj.BreakJointsOnDeath = false
	RagdollRigging.createRagdollJoints(self._obj.Parent, humanoid.RigType)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player then
		self._player = player

		self._remoteEvent = Instance.new("RemoteEvent")
		self._remoteEvent.Name = RagdollableConstants.REMOTE_EVENT_NAME
		self._remoteEvent.Parent = self._obj
		self._maid:GiveTask(self._remoteEvent)

		self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
			self:_handleServerEvent(...)
		end))
	else
		-- NPC
		self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj, function()
			self:_onRagdollChangedForNPC()
		end))

		self:_onRagdollChangedForNPC()
	end

	-- For fast debugging
	-- self._maid:GiveTask(AttributeUtils.bindToBinder(self._obj, "Ragdoll", self._ragdollBinder))

	return self
end

function Ragdollable:_onRagdollChangedForNPC()
	if self._ragdollBinder:Get(self._obj) then
		self:_setRagdollEnabled(true)
	else
		self:_setRagdollEnabled(false)
	end
end

function Ragdollable:_handleServerEvent(player, state)
	assert(self._player == player, "Bad player")

	if state then
		self._ragdollBinder:Bind(self._obj)
	else
		self._ragdollBinder:Unbind(self._obj)
	end

	self:_setRagdollEnabled(state)
end

function Ragdollable:_setRagdollEnabled(isEnabled)
	if isEnabled then
		if self._maid._ragdoll then
			return
		end

		self._maid._ragdoll = self:_enableServer()
	else
		self._maid._ragdoll = nil
	end
end

function Ragdollable:_enableServer()
	local maid = Maid.new()

	-- This will reset friction too
	RagdollRigging.createRagdollJoints(self._obj.Parent, self._obj.RigType)

	maid:GiveTask(RagdollUtils.setupState(self._obj))
	maid:GiveTask(RagdollUtils.setupMotors(self._obj))
	maid:GiveTask(RagdollUtils.setupHead(self._obj))
	maid:GiveTask(RagdollUtils.preventAnimationTransformLoop(self._obj))

	-- Do this after we setup motors
	HumanoidAnimatorUtils.stopAnimations(self._obj, 0)

	maid:GiveTask(self._obj.AnimationPlayed:Connect(function(track)
		track:Stop(0)
	end))

	return maid
end

return Ragdollable