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

		local head = brio:GetValue()
		local maid = brio:ToMaid()

		head.CanCollide = true

		maid:GiveTask(function()
			head.CanCollide = false
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

						-- Do motors
						maid:GiveTask(RagdollMotorUtils.suppressMotors(character, rigType, velocityReadings))

						humanoid:ChangeState(Enum.HumanoidStateType.Physics)
						maid:GiveTask(function()
							humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
						end)

						debug.profileend()
					end)
			else
				debug.profilebegin("initragdoll_nonowner")

				maid:GiveTask(RagdollMotorUtils.suppressJustRootPart(character, rigType))

				debug.profileend()
			end

			topMaid._current = maid
		else
			topMaid._current = nil
		end
	end))

	return topMaid
end


return RxRagdollUtils