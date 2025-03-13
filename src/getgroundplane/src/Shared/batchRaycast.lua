--!strict
--[=[
	Batch raycast utility function
	@private
	@class batchRaycast
]=]

local function batchRaycast(
	originList: {Vector3}, directionList: { Vector3 },
	ignoreListWorkingEnvironment: { Instance },
	ignoreFunc: (Instance) -> boolean, keepIgnoreListChanges: boolean
): { RaycastResult }

	local resultList = {}
	local initialIgnoreListLength = #ignoreListWorkingEnvironment

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = ignoreListWorkingEnvironment
	params.IgnoreWater = true

	for i in next, originList do
		local origin = originList[i]
		local direction = directionList[i]
		local target --we'll use these later maybe
		local offset
		while true do
			local result = workspace:Raycast(origin, direction, params)
			if ignoreFunc and result and ignoreFunc(result.Instance) then
				table.insert(ignoreListWorkingEnvironment, result.Instance)
				params.FilterDescendantsInstances = ignoreListWorkingEnvironment

				if not target then--initialize these
					target = origin + direction
					offset = 1e-3 / direction.Magnitude * direction
				end

				origin = result.Position - offset
				direction = target - origin
			else
				resultList[i] = result--may be nil
				break
			end
		end
	end

	if not keepIgnoreListChanges then
		for i = #ignoreListWorkingEnvironment, initialIgnoreListLength + 1, -1 do
			ignoreListWorkingEnvironment[i] = nil
		end
	end

	return resultList
end

return batchRaycast