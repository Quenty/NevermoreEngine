--!strict
--[=[
	See https://gist.github.com/Fraktality/4e394945c865263144263250d5a78f79

	@class CompiledBoundingBoxUtils
]=]

local CompiledBoundingBoxUtils = {}

--[=[
	Compiles a bounding box into a CFrame rotation matrix for easy
	usage.

	@param cframe CFrame
	@param size Vector3
	@return CFrame
]=]
function CompiledBoundingBoxUtils.compileBBox(cframe: CFrame, size: Vector3): CFrame
	-- stylua: ignore
	return CFrame.fromMatrix(
		cframe.Position,
		cframe.XVector/size.X,
		cframe.YVector/size.Y,
		cframe.ZVector/size.Z
	):Inverse()
end

--[=[
	Point-obb occupancy test
	@param point Vector3
	@param bbox CFrame
	@return boolean
]=]
function CompiledBoundingBoxUtils.testPointBBox(point: Vector3, bbox: CFrame): boolean
	local objPos = bbox * point

	-- stylua: ignore
	return
		math.abs(objPos.X) < 0.5 and
		math.abs(objPos.Y) < 0.5 and
		math.abs(objPos.Z) < 0.5
end

return CompiledBoundingBoxUtils