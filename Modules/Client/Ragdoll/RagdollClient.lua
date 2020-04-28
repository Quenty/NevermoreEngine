--- Client side ragdolling meant to be used with a binder
-- @classmod RagdollClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local CameraStackService = require("CameraStackService")
local CharacterUtils = require("CharacterUtils")
local HapticFeedbackUtils = require("HapticFeedbackUtils")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")
local RagdollConstants = require("RagdollConstants")
local RagdollRigging = require("RagdollRigging")
local RagdollUtils = require("RagdollUtils")

local RagdollClient = setmetatable({}, BaseObject)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

function RagdollClient.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), RagdollClient)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		self._obj.BreakJointsOnDeath = false

		self:_setupPhysicsLocal()

		self._maid:GiveTask(RagdollUtils.setupState(self._obj))
		self._maid:GiveTask(RagdollUtils.setupHead(self._obj))

		self:_setupHapticFeedback()

		self:_setupCameraShake(CameraStackService:GetImpulseCamera())

		-- Do this after we setup motors
		HumanoidAnimatorUtils.stopAnimations(humanoid)

		self._maid:GiveTask(RunService.Stepped:Connect(function()
			HumanoidAnimatorUtils.stopAnimations(humanoid)
		end))
	end

	return self
end

-- TODO: Move out of this open source module
function RagdollClient:_setupCameraShake(impulseCamera)
	impulseCamera:Impulse(Vector3.new(5*(math.random()-0.5), 0, 0))

	local head = self._obj.Parent:FindFirstChild("Head")
	if not head then
		return
	end

	local lastVelocity = head.Velocity
	self._maid:GiveTask(RunService.RenderStepped:Connect(function()

		local cameraCFrame = Workspace.CurrentCamera.CFrame

		local velocity = head.Velocity

		local dVelocity = velocity - lastVelocity
		if dVelocity.magnitude >= 0 then
			impulseCamera:Impulse(cameraCFrame:vectorToObjectSpace(-0.1*cameraCFrame.lookVector:Cross(dVelocity)))
		end

		lastVelocity = velocity
	end))
end

function RagdollClient:_setupPhysicsLocal()
	-- If we're missing our RemoteEvent to notify the server that we've started simulating our
	-- ragdoll so it can authoritatively replicate the joint removal, don't ragdoll at all.
	local remote = self._obj:FindFirstChild(RagdollConstants.RAGDOLL_REMOTE_EVENT)
	if not remote then
		warn("[RagdollClient] - No RagdollRemoteEvent, we must be Ragdollable before ragdolling")
		return
	end

	-- Hopefully these are already created. Intent here is to reset friction.
	RagdollRigging.createRagdollJoints(self._obj.Parent, self._obj.RigType)

	local character = self._obj.Parent

	-- We first disable the motors on the network owner (the player that owns this character).
	--
	-- This way there is no visible round trip hitch. By the time the server receives the joint
	-- break physics data for the child parts should already be available. Seamless transition.
	--
	-- If we initiated ragdoll by disabling joints on the server there's a visible hitch while the
	-- server waits at least a full round trip time for the network owner to receive the joint
	-- removal, start simulating the ragdoll, and replicate physics data. Meanwhile the other body
	-- parts would be frozen in air on the server and other clients until physics data arives from
	-- the owner. The ragdolled player wouldn't see it, but other players would.
	--
	-- We also specifically do not disable the root joint on the client so we can maintain a
	-- consistent mechanism and network ownership unit root. If we did disable the root joint we'd
	-- be creating a new, seperate network ownership unit that we would have to wait for the server
	-- to assign us network ownership of before we would start simulating and replicating physics
	-- data for it, creating an additional round trip hitch on our end for our own character.
	local motors = RagdollRigging.disableMotors(character, self._obj.RigType)

	self._maid:GiveTask(function()
		for _, motor in pairs(motors) do
			motor.Enabled = true
		end
	end)

	-- Apply velocities from animation to the child parts to mantain visual momentum.
	--
	-- This should be done on the network owner's side just after disabling the kinematic joint so
	-- the child parts are split off as seperate dynamic bodies. For consistent animation times and
	-- visual momentum we want to do this on the machine that controls animation state for the
	-- character and will be simulating the ragdoll, in this case the client.
	--
	-- It's also important that this is called *before* any animations are canceled or changed after
	-- death! Otherwise there will be no animations to get velocities from or the velocities won't
	-- be consistent!
	local animator = self._obj:FindFirstChildWhichIsA("Animator")
	if animator then
		animator:ApplyJointVelocities(motors)
	end

	-- Tell the server that we started simulating our ragdoll
	remote:FireServer()
end

function RagdollClient:_setupHapticFeedback()
	local lastInputType = UserInputService:GetLastInputType()
	if not HapticFeedbackUtils.setSmallVibration(lastInputType, 1) then
		return
	end

	local alive = true
	self._maid:GiveTask(function()
		alive = false
	end)

	spawn(function()
		for i=1, 0, -0.1 do
			HapticFeedbackUtils.setSmallVibration(lastInputType, i)
			wait(0.05)
		end
		HapticFeedbackUtils.setSmallVibration(lastInputType, 0)

		if alive then
			self._maid:GiveTask(function()
				HapticFeedbackUtils.smallVibrate(lastInputType)
			end)
		end
	end)
end

function RagdollClient:_setupState()
	self._obj:ChangeState(Enum.HumanoidStateType.Physics)
	self._maid:GiveTask(function()
		self._obj:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

function RagdollClient:_setupCamera()
	local model = self._obj.Parent
	if not model then
		return
	end

	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
	if not torso then
		warn("[RagdollClient] - No Torso")
		return
	end

	Workspace.CurrentCamera.CameraSubject = torso

	self._maid:GiveTask(function()
		Workspace.CurrentCamera.CameraSubject = self._obj
	end)
end

return RagdollClient