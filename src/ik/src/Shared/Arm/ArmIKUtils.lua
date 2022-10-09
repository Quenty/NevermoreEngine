--[=[
	@class ArmIKUtils
]=]

local require = require(script.Parent.loader).load(script)

local RagdollConstants = require("RagdollConstants")
local RxR15Utils = require("RxR15Utils")
local Maid = require("Maid")

local ArmIKUtils = {}

function ArmIKUtils.ensureMotorAnimated(character, armName)
	local topMaid = Maid.new()

	local function disable(brio)
		if brio:IsDead() then
			return
		end

		local motor = brio:GetValue()
		local maid = brio:ToMaid()

		motor:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, true)
		maid:GiveTask(function()
			motor:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false)
		end)
	end

	topMaid:GiveTask(RxR15Utils.observeRigMotorBrio(character, armName .. "UpperArm", armName .. "Shoulder"):Subscribe(disable))
	topMaid:GiveTask(RxR15Utils.observeRigMotorBrio(character, armName .. "LowerArm", armName .. "Elbow"):Subscribe(disable))
	topMaid:GiveTask(RxR15Utils.observeRigMotorBrio(character, armName .. "Hand", armName .."Wrist"):Subscribe(disable))

	return topMaid
end

return ArmIKUtils