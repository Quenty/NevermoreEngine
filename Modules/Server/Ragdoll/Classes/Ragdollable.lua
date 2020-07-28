---
-- @classmod Ragdollable
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local RagdollRigging = require("RagdollRigging")
local RagdollableConstants = require("RagdollableConstants")
local CharacterUtils = require("CharacterUtils")
local RagdollUtils = require("RagdollUtils")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")
local Maid = require("Maid")
local RagdollBindersServer = require("RagdollBindersServer")

local Ragdollable = setmetatable({}, BaseObject)
Ragdollable.ClassName = "Ragdollable"
Ragdollable.__index = Ragdollable

function Ragdollable.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), Ragdollable)

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
		self._maid:GiveTask(RagdollBindersServer.Ragdoll:ObserveInstance(self._obj, function()
			self:_onRagdollChangedForNPC()
		end))

		self:_onRagdollChangedForNPC()
	end

	return self
end

function Ragdollable:_onRagdollChangedForNPC()
	if RagdollBindersServer.Ragdoll:Get(self._obj) then
		self:_setRagdollEnabled(true)
	else
		self:_setRagdollEnabled(false)
	end
end

function Ragdollable:_handleServerEvent(player, state)
	assert(self._player == player)

	if state then
		RagdollBindersServer.Ragdoll:Bind(self._obj)
	else
		RagdollBindersServer.Ragdoll:Unbind(self._obj)
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