--- Utilities involving orthogonal Vector3s
-- @module OrthogonalUtils

local OrthogonalUtils = {}

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

function OrthogonalUtils.snapCFrameTo(cframe, snapTo)
	local options = {
		snapTo.LookVector, -- front
		-snapTo.LookVector,
		snapTo.RightVector,
		-snapTo.RightVector,
		snapTo.UpVector,
		-snapTo.UpVector,
	}

	local rightVector = OrthogonalUtils.getClosestVector(options, cframe.RightVector)
	local upVector = OrthogonalUtils.getClosestVector(options, cframe.UpVector)

	return CFrame.fromMatrix(cframe.Position, rightVector, upVector)
end

return OrthogonalUtils