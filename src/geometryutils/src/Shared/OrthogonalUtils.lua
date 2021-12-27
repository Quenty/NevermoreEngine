--[=[
	Utilities involving orthogonal Vector3s
	@class OrthogonalUtils
]=]

local OrthogonalUtils = {}

--[=[
	Decompose the CFrame
	@param cframe CFrame
	return { Vector3 }
]=]
function OrthogonalUtils.decomposeCFrameToVectors(cframe)
	return  {
		cframe.LookVector, -- front
		-cframe.LookVector,
		cframe.RightVector,
		-cframe.RightVector,
		cframe.UpVector,
		-cframe.UpVector,
	}
end

--[=[
	Gets the closest vectors to another vector.

	@param options { Vector3 } -- normals
	@param unitVector Vector3
	return Vector3?
]=]
function OrthogonalUtils.getClosestVector(options, unitVector)
	local best = nil
	local bestAngle = -math.huge
	for _, option in pairs(options) do
		local dotAngle = option:Dot(unitVector)
		if dotAngle > bestAngle then
			bestAngle = dotAngle
			best = option
		end
	end

	return best
end

--[=[
	Snaps a CFrame to another one

	@param cframe CFrame
	@param snapToCFrame CFrame
	return CFrame
]=]
function OrthogonalUtils.snapCFrameTo(cframe, snapToCFrame)
	local options = OrthogonalUtils.decomposeCFrameToVectors(snapToCFrame)
	local rightVector = OrthogonalUtils.getClosestVector(options, cframe.RightVector)
	local upVector = OrthogonalUtils.getClosestVector(options, cframe.UpVector)

	assert(rightVector, "Failed to find rightVector")
	assert(upVector, "Failed to find upVector")

	return CFrame.fromMatrix(cframe.Position, rightVector, upVector)
end

return OrthogonalUtils