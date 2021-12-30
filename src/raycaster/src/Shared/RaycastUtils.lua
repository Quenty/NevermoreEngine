--[=[
	General utility for raycasting
	Author: Quenty, AxisAngle

	@class RaycastUtils
]=]

local RaycastUtils = {}

--works for non-convex
--assumes non-selfintersecting
--what is the first exit along this line segment?
function RaycastUtils.raycastSingleExit(origin, direction, part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = {part}

	local resultFinal = workspace:Raycast(origin + direction, -direction, params)

	return resultFinal
end

function RaycastUtils.ignoreCanCollideFalse(part)
	return not part.CanCollide
end

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
		local result = workspace:Raycast(origin, direction, params)
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