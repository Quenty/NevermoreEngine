--[=[
	@class ArmIKUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local RagdollMotorData = require("RagdollMotorData")
local RxR15Utils = require("RxR15Utils")

local ArmIKUtils = {}

function ArmIKUtils.ensureMotorAnimated(character: Model, armName)
	local topMaid = Maid.new()

	local function disable(brio)
		if brio:IsDead() then
			return
		end

		local maid, motor = brio:ToMaidAndValue()
		local ragdollMotorData = RagdollMotorData:Create(motor)

		ragdollMotorData.IsMotorAnimated.Value = true
		maid:GiveTask(function()
			ragdollMotorData.IsMotorAnimated.Value = false
		end)
	end

	topMaid:GiveTask(
		RxR15Utils.observeRigMotorBrio(character, armName .. "UpperArm", armName .. "Shoulder"):Subscribe(disable)
	)
	topMaid:GiveTask(
		RxR15Utils.observeRigMotorBrio(character, armName .. "LowerArm", armName .. "Elbow"):Subscribe(disable)
	)
	topMaid:GiveTask(
		RxR15Utils.observeRigMotorBrio(character, armName .. "Hand", armName .. "Wrist"):Subscribe(disable)
	)

	return topMaid
end

return ArmIKUtils
