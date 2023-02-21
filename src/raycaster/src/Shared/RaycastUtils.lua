--[=[
	General utility for raycasting
	Author: Quenty, AxisAngle

	@class RaycastUtils
]=]

local Workspace = game:GetService("Workspace")

local RaycastUtils = {}

--[=[
	What is the first exit along this line segment?

	* Works for non-convex
	* Assumes non-selfintersecting

	@param origin Vector3
	@param direction Vector3
	@param part BasePart
	@return RaycastResult
]=]
function RaycastUtils.raycastSingleExit(origin, direction, part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {part}

	local resultFinal = Workspace:Raycast(origin + direction, -direction, params)

	return resultFinal
end

--[=[
	Ignore function that ignores can collide false parts.

	@param part BasePart
	@return boolean
]=]
function RaycastUtils.ignoreCanCollideFalse(part)
	return not part.CanCollide
end

--[=[
	Raycasts from a given point and repeatedly raycasts until the ignore function
	does not apply.

	@param origin Vector3
	@param direction Vector3
	@param ignoreListWorkingEnvironment { Instance }
	@param ignoreFunc callback
	@param keepIgnoreListChanges boolean?
	@param ignoreWater boolean?
	@return RaycastResult
]=]
function RaycastUtils.raycast(
	origin, direction,
	ignoreListWorkingEnvironment,
	ignoreFunc, keepIgnoreListChanges,
	ignoreWater
)
	local resultFinal
	local initialIgnoreListLength = #ignoreListWorkingEnvironment

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = ignoreListWorkingEnvironment
	params.IgnoreWater = ignoreWater and true or false

	while true do
		local result = Workspace:Raycast(origin, direction, params)
		if ignoreFunc and result and ignoreFunc(result.Instance) then
			table.insert(ignoreListWorkingEnvironment, result.Instance)
			params.FilterDescendantsInstances = ignoreListWorkingEnvironment
		else
			resultFinal = result
			break
		end
	end

	if not keepIgnoreListChanges then
		for i = #ignoreListWorkingEnvironment, initialIgnoreListLength + 1, -1 do
			ignoreListWorkingEnvironment[i] = nil
		end
	end

	return resultFinal
end

return RaycastUtils