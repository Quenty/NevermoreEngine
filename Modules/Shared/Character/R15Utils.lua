--- Utility methods for R15
-- @module R15Utils

local R15Utils = {}

function R15Utils.getUpperTorso(humanoid)
	local character = humanoid.Parent
	if not character then
		return nil
	end

	return character:FindFirstChild("UpperTorso")
end

function R15Utils.getLeftShoulderRigAttachment(humanoid)
	local upperTorso = R15Utils.getUpperTorso(humanoid)
	if not upperTorso then
		return nil
	end

	return upperTorso:FindFirstChild("LeftShoulderRigAttachment")
end

function R15Utils.getRightShoulderRigAttachment(humanoid)
	local upperTorso = R15Utils.getUpperTorso(humanoid)
	if not upperTorso then
		return nil
	end

	return upperTorso:FindFirstChild("RightShoulderRigAttachment")
end


return R15Utils