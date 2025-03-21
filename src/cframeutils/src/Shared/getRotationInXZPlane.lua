--!strict
--[=[
	Utility function to get rotation in the XZ plane.
	@class getRotationInXZPlane
]=]

--[=[
	Computes the rotation in the XZ plane relative to the origin.

	:::tip
	This function can be used to "flatten" a rotation so we just get the XZ rotation, which
	is the rotation you would see if we are looking directly top-down on the object.
	:::

	@param cframe CFrame
	@return CFrame -- The CFrame in the XZ plane
	@within getRotationInXZPlane
]=]
local function getRotationInXZPlane(cframe: CFrame): CFrame
	-- stylua: ignore
	local _, _, _,
	      _, _, zx,
	      _, _, _,
	      _, _, zz = cframe:GetComponents()

	local back = Vector3.new(zx, 0, zz).Unit
	if back ~= back then
		return cframe -- we're looking straight down
	end

	local top = Vector3.new(0, 1, 0)
	local right = top:Cross(back)

	-- stylua: ignore
	return CFrame.new(
		cframe.X, cframe.Y, cframe.Z,
		right.X, top.X, back.X,
		right.Y, top.Y, back.Y,
		right.Z, top.Z, back.Z
	)
end

return getRotationInXZPlane
