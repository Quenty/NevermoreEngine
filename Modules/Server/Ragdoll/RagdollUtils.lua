--- Utility mehtods for ragdolling
-- @module RagdollUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RagdollRigtypes = require("RagdollRigtypes")

local RagdollUtils = {}

function RagdollUtils.createNoCollision(humanoid)
	local model = humanoid.Parent or error("Humanoid must have parent")

	local created = {}
	for _, pair in pairs(RagdollRigtypes.getNoCollisions(model, humanoid.RigType)) do
		local noCollision = Instance.new("NoCollisionConstraint")
		noCollision.Name = "RagdollNoCollision"
		noCollision.Part0 = pair[1]
		noCollision.Part1 = pair[2]
		noCollision.Parent = pair[1]

		table.insert(created, noCollision)
	end

	return created
end

function RagdollUtils.createBallJoints(humanoid)
	local joints = {}

	local model = humanoid.Parent or error("Humanoid must have parent")
	local attachments = RagdollRigtypes.getAttachments(model, humanoid.RigType)


	-- Instantiate BallSocketConstraints:
	for name, objects in pairs(attachments) do
		local parent = model:FindFirstChild(name)
		if parent then
			local constraint = Instance.new("BallSocketConstraint")
			constraint.Name = "RagdollBallSocketConstraint"
			constraint.Attachment0 = objects.attachment0
			constraint.Attachment1 = objects.attachment1
			constraint.LimitsEnabled = true
			constraint.UpperAngle = objects.limits.UpperAngle
			constraint.TwistLimitsEnabled = true
			constraint.TwistLowerAngle = objects.limits.TwistLowerAngle
			constraint.TwistUpperAngle = objects.limits.TwistUpperAngle

			-- if parent.Name == "Head" then
			-- 	constraint.LimitsEnabled = true
			-- 	constraint.UpperAngle = 60
			-- 	constraint.TwistLimitsEnabled = true
			-- 	constraint.TwistLowerAngle = -60
			-- 	constraint.TwistUpperAngle = 60
			-- end

			constraint.Parent = parent
			table.insert(joints, constraint)
		end
	end

	return joints

end

function RagdollUtils.getMotors(humanoid)
	local model = humanoid.Parent or error("Humanoid must have parent")

	local rootPart = humanoid.RootPart
	local motors = {}

	for _, motor in pairs(model:GetDescendants()) do
		if motor:IsA("Motor6D") then
			if motor.Part0 ~= rootPart and motor.Part1 ~= rootPart then
				table.insert(motors, motor)
			end
		end
	end

	return motors
end

return RagdollUtils