--- Utility function to get rotation in the XZ plane
-- @module getRotationInXZPlane

--- Get's the rotation in the XZ plane relative to the origin
-- @param cframe The CFrame
-- @return The CFrame in the XZ plane
return function(cframe)
	local _,_,_,
	      _,_,zx,
	      _,_,_,
	      _,_,zz = cframe:GetComponents()

	local back = Vector3.new(zx, 0, zz).unit
	if back ~= back then
		return cframe -- we're looking straight down
	end

	local top = Vector3.new(0, 1, 0)
	local right = top:Cross(back)

	return CFrame.new(
		cframe.X, cframe.Y, cframe.Z,
		right.X, top.X, back.X,
		right.Y, top.Y, back.Y,
		right.Z, top.Z, back.Z
	)
end