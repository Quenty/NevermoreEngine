--- General humanoid utility code.
-- @module HumanoidUtils
-- @alias HumanoidUtils

local HumanoidUtils = {}

--- Retrieves a humanoid from a descendant (Players only).
-- @param descendant Child of a humanoid model, like a limb
-- @return Humanoid
function HumanoidUtils.getHumanoid(descendant)
	local character = descendant
	while character do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		character = character:FindFirstAncestorOfClass("Model")
	end

	return nil
end

--- Forcefully unseats the humanoid. Useful when teleporting humanoid
function HumanoidUtils.forceUnseatHumanoid(humanoid)
	if humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end

		humanoid.SeatPart:Sit(nil)
	end
	humanoid.Sit = false
end

return HumanoidUtils