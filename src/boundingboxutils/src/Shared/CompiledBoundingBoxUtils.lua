--[=[
	See https://gist.github.com/Fraktality/4e394945c865263144263250d5a78f79

	@class CompiledBoundingBoxUtils
]=]
--

local CompiledBoundingBoxUtils = {}

--[=[
	Compiles a bounding box into a CFrame rotation matrix for easy
	usage.

	@param cframe CFrame
	@param size Vector3
	@return CFrame
]=]
function CompiledBoundingBoxUtils.compileBBox(cframe, size)
	return CFrame.fromMatrix(
		cframe.Position,
		cframe.XVector/size.x,
		cframe.YVector/size.y,
		cframe.ZVector/size.z
	):inverse()
end

--[=[
	Point-obb occupancy test
	@param pt Vector3
	@param bbox CFrame
	@return boolean
]=]
function CompiledBoundingBoxUtils.testPointBBox(pt, bbox)
	local objPos = bbox*pt
	return
		math.abs(objPos.x) < 0.5 and
		math.abs(objPos.y) < 0.5 and
		math.abs(objPos.z) < 0.5
end

return CompiledBoundingBoxUtils