--!strict
--[=[
	Utility methods to work with Roblox humanoids.

	@class HumanoidUtils
]=]

local HumanoidUtils = {}

--[=[
	Retrieves a humanoid from a descendant.
	@param descendant Instance -- Child of a humanoid model, like a limb

	@return Humanoid?
]=]
function HumanoidUtils.getHumanoid(descendant: Instance): Humanoid?
	local character: Instance? = descendant
	while character do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		character = character:FindFirstAncestorOfClass("Model")
	end

	return nil
end

--[=[
	Forcefully unseats the humanoid. Useful when teleporting humanoid.
	Definitely a non-intuitive operation to do safely.

	@param humanoid Humanoid
]=]
function HumanoidUtils.forceUnseatHumanoid(humanoid: Humanoid)
	local seatPart: (Seat | VehicleSeat)? = humanoid.SeatPart
	if seatPart ~= nil then
		local weld = seatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end

		(seatPart :: any):Sit(nil)
	end

	humanoid.Sit = false
end

return HumanoidUtils
