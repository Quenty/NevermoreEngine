---
-- @module CompiledBoundingBoxUtils
-- https://gist.github.com/Fraktality/4e394945c865263144263250d5a78f79

local CompiledBoundingBoxUtils = {}

function CompiledBoundingBoxUtils.compileBBox(cframe, size)
	return CFrame.fromMatrix(
		cframe.p,
		cframe.XVector/size.x,
		cframe.YVector/size.y,
		cframe.ZVector/size.z
	):inverse()
end

-- point-obb occupancy test
function CompiledBoundingBoxUtils.testPointBBox(pt, bbox)
	local objPos = bbox*pt
	return
		math.abs(objPos.x) < 0.5 and
		math.abs(objPos.y) < 0.5 and
		math.abs(objPos.z) < 0.5
end

return CompiledBoundingBoxUtils