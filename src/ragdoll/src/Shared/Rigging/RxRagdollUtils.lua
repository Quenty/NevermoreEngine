--[=[
	Utility methods to assist with rigging the ragdoll in real-time.

	@class RxRagdollUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")
local RagdollMotorUtils = require("RagdollMotorUtils")
local CharacterUtils = require("CharacterUtils")

local RxRagdollUtils = {}

function RxRagdollUtils.observeRigType(humanoid)
	return RxInstanceUtils.observeProperty(humanoid, "RigType")
end

function RxRagdollUtils.observeCharacterBrio(humanoid)
	return RxInstanceUtils.observePropertyBrio(humanoid, "Parent", function(value)
		return value ~= nil
	end)
end

function RxRagdollUtils.suppressRootPartCollision(character)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxR15Utils.observeCharacterPartBrio(character, "HumanoidRootPart"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local rootPart = brio:GetValue()
		local maid = brio:ToMaid()

		local oldProperties = rootPart.CustomPhysicalProperties
		local current = oldProperties or PhysicalProperties.new(rootPart.Material)

		-- Reduce impact of rootPart mass as much as possible.
		rootPart.CustomPhysicalProperties = PhysicalProperties.new(
				0.01,
				current.Friction,
				current.Elasticity,
				current.FrictionWeight,
				current.ElasticityWeight)
		rootPart.CanCollide = false
		maid:GiveTask(function()
			rootPart.CustomPhysicalProperties = oldProperties
			rootPart.CanCollide = true
		end)
	end))

	return topMaid
end

function RxRagdollUtils.enforceHeadCollision(character)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxR15Utils.observeCharacterPartBrio(character, "Head"):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, head = brio:ToMaidAndValue()
		head.CanCollide = true

		maid:GiveTask(function()
			head.CanCollide = false
		end)
	end))

	return topMaid
end

function RxRagdollUtils.enforceHumanoidStateMachineOff(character, humanoid)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	local topMaid = Maid.new()

	topMaid:GiveTask(RxInstanceUtils.observePropertyBrio(humanoid, "EvaluateStateMachine", function(evaluateStateMachine)
		return not evaluateStateMachine
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		maid:GiveTask(RxRagdollUtils.enforceLimbCollisions(character))
	end))

	return topMaid
end

function RxRagdollUtils.enforceLimbCollisions(character)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")

	local topMaid = Maid.new()

	local LIMB_NAMES = {
		-- R6
		["Left Arm"] = true;
		["Right Arm"] = true;
		["Left Leg"] = true;
		["Right Leg"] = true;

		-- R15
		["LeftUpperArm"] = true;
		["LeftLowerArm"] = true;
		["LeftHand"] = true;
		["LeftUpperLeg"] = true;
		["LeftLowerLeg"] = true;
		["LeftFoot"] = true;
		["RightUpperArm"] = true;
		["RightLowerArm"] = true;
		["RightHand"] = true;
		["RightUpperLeg"] = true;
		["RightLowerLeg"] = true;
		["RightFoot"] = true;
	}

	topMaid:GiveTask(RxInstanceUtils.observeChildrenBrio(character, function(child)
		return child:IsA("BasePart") and LIMB_NAMES[child.Name]
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, part = brio:ToMaidAndValue()
		part.CanCollide = true
		maid:GiveTask(function()
			part.CanCollide = false
		end)
	end))

	return topMaid
end


function RxRagdollUtils.runLocal(humanoid)
	local topMaid = Maid.new()

	topMaid:GiveTask(RxBrioUtils.flatCombineLatest({
		character = RxRagdollUtils.observeCharacterBrio(humanoid);
		rigType = RxRagdollUtils.observeRigType(humanoid);
	}):Subscribe(function(state)
		if state.character and state.rigType then
			local character = state.character
			local rigType = state.rigType

			local maid = Maid.new()

			local player = CharacterUtils.getPlayerFromCharacter(humanoid)
			-- This velocity work only really needs to occur on the network owner and on the server
			-- since the server will replicate all changes over to the client.
			if RunService:IsServer() or player == Players.LocalPlayer then
				maid:GivePromise(RagdollMotorUtils.promiseVelocityRecordings(character, rigType))
					:Then(function(velocityReadings)
						debug.profilebegin("initragdoll")

						maid:GiveTask(RxRagdollUtils.suppressRootPartCollision(character, rigType))
						maid:GiveTask(RxRagdollUtils.enforceHeadCollision(character))
						maid:GiveTask(RxRagdollUtils.enforceHumanoidStateMachineOff(character, humanoid))

						-- Do motors
						maid:GiveTask(RagdollMotorUtils.suppressMotors(character, rigType, velocityReadings))
						maid:GiveTask(RxRagdollUtils.enforceHumanoidState(humanoid))

						debug.profileend()
					end)
			else
				debug.profilebegin("initragdoll_nonowner")

				maid:GiveTask(RagdollMotorUtils.suppressJustRootPart(character, rigType))
				maid:GiveTask(RxRagdollUtils.enforceHumanoidState(humanoid))

				debug.profileend()
			end

			topMaid._current = maid
		else
			topMaid._current = nil
		end
	end))

	return topMaid
end

function RxRagdollUtils.enforceHumanoidState(humanoid)
	local maid = Maid.new()
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- If you're holding a humanoid and jump, then the humanoid state
	-- changes to your humanoid's state.

	maid._keepAsPhysics = humanoid.StateChanged:Connect(function(_old, new)
		if new ~= Enum.HumanoidStateType.Physics
			and new ~= Enum.HumanoidStateType.Dead then

			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end)

	maid:GiveTask(function()
		maid._keepAsPhysics = nil

		if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	return maid
end


return RxRagdollUtils