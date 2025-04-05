--!strict
--[=[
	Utility functions for surfaces
	@class SurfaceUtils
]=]

local SurfaceUtils = {}

local UP = Vector3.new(0, 1, 0)
local BACK = Vector3.new(0, 0, 1)
local EXTRASPIN = CFrame.fromEulerAnglesXYZ(math.pi / 2, 0, 0)

local function getTranstionBetween(v1: Vector3, v2: Vector3, pitchAxis: Vector3): CFrame
	local dot = v1:Dot(v2)
	if dot > 0.99999 then
		return CFrame.new()
	elseif dot < -0.99999 then
		return CFrame.fromAxisAngle(pitchAxis, math.pi)
	end
	return CFrame.fromAxisAngle(v1:Cross(v2), math.acos(dot))
end

--[=[
	Finds a CFrame on the surface.

	:::warning
	This only works with Part objects that are rectangles.
	:::

	@param part Part
	@param lnormal Vector3
	@return CFrame
]=]
function SurfaceUtils.getSurfaceCFrame(part: BasePart, lnormal: Vector3): CFrame
	local transition = getTranstionBetween(UP, lnormal, BACK)
	return part.CFrame * transition * EXTRASPIN
end

return SurfaceUtils