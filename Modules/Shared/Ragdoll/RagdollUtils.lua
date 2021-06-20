--- Utility mehtods for ragdolling. See Ragdoll.lua and RagdollClient.lua for implementation details
-- @module RagdollUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Maid = require("Maid")
local promiseChild = require("promiseChild")
local RagdollRigging = require("RagdollRigging")
local CharacterUtils = require("CharacterUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local RagdollConstants = require("RagdollConstants")

local RagdollUtils = {}

local EMPTY_FUNCTION = function() end

function RagdollUtils.setupState(humanoid)
	local maid = Maid.new()

	local function updateState()
		-- If we change state to dead then it'll flicker back and forth firing off
		-- the dead event multiple times.

		if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end

	local function teleportRootPartToUpperTorso()
		-- This prevents clipping into the ground, mostly, at least on R15, on thin parts

		if CharacterUtils.getPlayerFromCharacter(humanoid) ~= Players.LocalPlayer then
			return
		end

		local rootPart = humanoid.RootPart
		if not rootPart then
			return
		end

		local character = humanoid.Parent
		if not character then
			return
		end

		local upperTorso = character:FindFirstChild("UpperTorso")
		if not upperTorso then
			return
		end

		rootPart.CFrame = upperTorso.CFrame
	end

	maid:GiveTask(function()
		maid:DoCleaning() -- GC other events
		teleportRootPartToUpperTorso()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	maid:GiveTask(humanoid.StateChanged:Connect(updateState))
	updateState()

	return maid
end

-- We need this on all clients/servers to override animations!
function RagdollUtils.preventAnimationTransformLoop(humanoid)
	local maid = Maid.new()

	local character = humanoid.Parent
	if not character then
		warn("[RagdollUtils.preventAnimationTransformLoop] - No character")
		return maid
	end

	maid:GivePromise(promiseChild(humanoid.Parent, "LowerTorso"))
		:Then(function(lowerTorso)
			return promiseChild(lowerTorso, "Root")
		end)
		:Then(function(root)
			-- This may desync the server and the client, but will result in
			-- no teleporting on the client.
			local lastTransform = root.Transform

			maid:GiveTask(RunService.Stepped:Connect(function()
				root.Transform = lastTransform
			end))
		end)

	return maid
end

function RagdollUtils.setupMotors(humanoid)
	local character = humanoid.Parent
	local rigType = humanoid.RigType

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
	local motors = RagdollRigging.getMotors(character, rigType)

	local maid = Maid.new()

	local function updateMotor(motor)
		if motor:GetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME) then
			motor.Enabled = true
		else
			motor.Enabled = false
		end
	end

	-- Disable all regular joints:
	for _, motor in pairs(motors) do
		maid:GiveTask(motor:GetAttributeChangedSignal(RagdollConstants.IS_MOTOR_ANIMATED_NAME)
			:Connect(function()
				updateMotor(motor)
			end))
		updateMotor(motor)

		maid:GiveTask(function()
			motor.Enabled = true
		end)
	end

	-- Set the root part to non-collide
	local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.CanCollide = false
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.CanCollide = true
	end

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
	local animator = humanoid:FindFirstChildWhichIsA("Animator")
	if animator then
		animator:ApplyJointVelocities(motors)
	end

	return function()
		maid:DoCleaning()
	end
end

function RagdollUtils.setupHead(humanoid)
	local model = humanoid.Parent
	if not model then
		return EMPTY_FUNCTION
	end

	local head = model:FindFirstChild("Head")
	if not head then
		return EMPTY_FUNCTION
	end

	if head:IsA("MeshPart") then
		return EMPTY_FUNCTION
	end

	local originalSizeValue = head:FindFirstChild("OriginalSize")
	if not originalSizeValue then
		return EMPTY_FUNCTION
	end

	local specialMesh = head:FindFirstChildWhichIsA("SpecialMesh")
	if not specialMesh then
		return EMPTY_FUNCTION
	end

	if specialMesh.MeshType ~= Enum.MeshType.Head then
		return EMPTY_FUNCTION
	end

	-- More accurate physics for heads! Heads start at 2,1,1 (at least they used to)
	local maid = Maid.new()
	local lastHeadScale

	maid:GiveTask(RxValueBaseUtils.observe(humanoid, "NumberValue", "HeadScale")
		:Subscribe(function(headScale)
			lastHeadScale = headScale

			head.Size = Vector3.new(1, 1, 1)*headScale
		end))

	-- Cleanup and reset head scale
	maid:GiveTask(function()
		if lastHeadScale then
			head.Size = originalSizeValue.Value*lastHeadScale
		end
	end)

	return maid
end

return RagdollUtils