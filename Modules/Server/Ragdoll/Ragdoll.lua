--- Base class for ragdolls, meant to be used with binders
-- @classmod Ragdoll

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local RagdollRigging = require("RagdollRigging")
local RagdollConstants = require("RagdollConstants")
local RagdollUtils = require("RagdollUtils")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")

local Ragdoll = setmetatable({}, BaseObject)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

function Ragdoll.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), Ragdoll)

	self._obj.BreakJointsOnDeath = false

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player then
		self._remoteEvent = self._obj:FindFirstChild(RagdollConstants.RAGDOLL_REMOTE_EVENT)
		if self._remoteEvent then
			self._maid._remoteEventConn = self._remoteEvent.OnServerEvent:Connect(function()
				self._maid._remoteEventConn = nil
				self:_ragdoll()
			end)
		else
			warn("[Ragdoll] - Must setup Ragdollable before ragdolling client character")
		end
	else
		-- NPC
		self:_ragdoll()
	end

	return self
end

function Ragdoll:_ragdoll()
	-- This will reset friction too
	RagdollRigging.createRagdollJoints(self._obj.Parent, self._obj.RigType)

	self:_setupMotors()
	self._maid:GiveTask(RagdollUtils.setupState(self._obj))
	self._maid:GiveTask(RagdollUtils.setupHead(self._obj))

	-- Do this after we setup motors
	HumanoidAnimatorUtils.stopAnimations(self._obj)
end

function Ragdoll:_setupMotors()
	local motors = RagdollRigging.disableMotors(self._obj.Parent, self._obj.RigType)
	local animator = self._obj:FindFirstChildWhichIsA("Animator")
	if animator then
		animator:ApplyJointVelocities(motors)
	end

	self._maid:GiveTask(function()
		for _, motor in pairs(motors) do
			motor.Enabled = true
		end
	end)
end


return Ragdoll