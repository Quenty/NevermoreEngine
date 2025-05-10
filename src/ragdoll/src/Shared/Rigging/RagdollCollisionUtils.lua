--[=[
	@class RagdollCollisionUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local RxBrioUtils = require("RxBrioUtils")
local RxR15Utils = require("RxR15Utils")

local RagdollCollisionUtils = {}

local R15_NO_COLLIDES = {
	{ "LowerTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftHand" },

	{ "LowerTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightHand" },

	{ "LeftUpperLeg", "RightUpperLeg" },

	{ "UpperTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightFoot" },

	{ "UpperTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftFoot" },

	-- Support weird R15 rigs
	{ "UpperTorso", "LeftLowerLeg" },
	{ "UpperTorso", "RightLowerLeg" },
	{ "LowerTorso", "LeftLowerLeg" },
	{ "LowerTorso", "RightLowerLeg" },

	{ "UpperTorso", "LeftLowerArm" },
	{ "UpperTorso", "RightLowerArm" },

	{ "Head", "LeftUpperArm" },
	{ "Head", "RightUpperArm" },

	-- Basically every other part
	{ "HumanoidRootPart", "LeftUpperArm" },
	{ "HumanoidRootPart", "RightUpperArm" },
	{ "HumanoidRootPart", "LeftLowerArm" },
	{ "HumanoidRootPart", "RightLowerArm" },
	{ "HumanoidRootPart", "LeftLowerLeg" },
	{ "HumanoidRootPart", "RightLowerLeg" },
	{ "HumanoidRootPart", "LeftUpperLeg" },
	{ "HumanoidRootPart", "RightUpperLeg" },
	{ "HumanoidRootPart", "Head" },
	{ "HumanoidRootPart", "LeftFoot" },
	{ "HumanoidRootPart", "RightFoot" },
	{ "HumanoidRootPart", "LeftHand" },
	{ "HumanoidRootPart", "RightHand" },
	{ "HumanoidRootPart", "UpperTorso" },
	{ "HumanoidRootPart", "LowerTorso" },
}

local R15_PARTS = {
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftUpperLeg",
	"RightUpperLeg",
	"Head",
	"LeftFoot",
	"RightFoot",
	"LeftHand",
	"RightHand",
	"UpperTorso",
	"LowerTorso",
}

local R6_NO_COLLIDES = {
	{ "Left Leg", "Right Leg" },
	{ "Head", "Right Arm" },
	{ "Head", "Left Arm" },

	{ "HumanoidRootPart", "Head" },
	{ "HumanoidRootPart", "Right Leg" },
	{ "HumanoidRootPart", "Right Arm" },
	{ "HumanoidRootPart", "Left Leg" },
	{ "HumanoidRootPart", "Left Arm" },
}

function RagdollCollisionUtils.getCollisionData(rigType: Enum.HumanoidRigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return R15_NO_COLLIDES
	elseif rigType == Enum.HumanoidRigType.R6 then
		return R6_NO_COLLIDES
	else
		error(string.format("[RagdollCollisionUtils] - Unknown rigType %q", tostring(rigType)))
	end
end

function RagdollCollisionUtils.preventCollisionAmongOthers(character: Model, part: BasePart)
	local topMaid = Maid.new()

	for _, partName in R15_PARTS do
		topMaid:GiveTask(RxR15Utils.observeCharacterPartBrio(character, partName):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local foundPart = brio:GetValue()

			local noCollide = Instance.new("NoCollisionConstraint")
			noCollide.Name = "RagdollNoCollisionConstraint_Animating"
			noCollide.Part0 = part
			noCollide.Part1 = foundPart
			noCollide.Parent = part
			maid:GiveTask(noCollide)
		end))
	end

	return topMaid
end

function RagdollCollisionUtils.ensureNoCollides(character: Model, rigType: Enum.HumanoidRigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local topMaid = Maid.new()

	for _, data in RagdollCollisionUtils.getCollisionData(rigType) do
		local part0Name, part1Name = unpack(data)

		local observable = RxBrioUtils.flatCombineLatest({
			part0 = RxR15Utils.observeCharacterPartBrio(character, part0Name),
			part1 = RxR15Utils.observeCharacterPartBrio(character, part1Name),
		})

		topMaid:GiveTask(observable:Subscribe(function(state)
			if state.part0 and state.part1 then
				local maid = Maid.new()

				local noCollide = Instance.new("NoCollisionConstraint")
				noCollide.Name = "RagdollNoCollisionConstraint"
				noCollide.Part0 = state.part0
				noCollide.Part1 = state.part1
				noCollide.Parent = state.part1
				maid:GiveTask(noCollide)

				topMaid[data] = maid
			else
				topMaid[data] = nil
			end
		end))
	end

	return topMaid
end

return RagdollCollisionUtils
