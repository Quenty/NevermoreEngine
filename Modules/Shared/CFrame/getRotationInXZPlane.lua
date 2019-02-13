--- Utility function to get rotation in the XZ plane
-- @module getRotationInXZPlane

--- Get's the back vector of a CFrame Value
-- @param cframe A CFrame, of which the vector will be retrieved
-- @return The back vector of the CFrame
local function getBackVector(cframe)
	local _,_,_,_,_,r6,_,_,r9,_,_,r12 = cframe:components()
	return Vector3.new(r6,r9,r12)
end

--- Get's the rotation in the XZ plane relative to the origin
-- @param cframe The CFrame
-- @return The CFrame in the XZ plane
return function(cframe)
	local back = getBackVector(cframe)
	back = Vector3.new(back.x, 0, back.z).unit
	local top = Vector3.new(0, 1, 0)

	local right = top:Cross(back)

	return CFrame.new(cframe.x, cframe.y, cframe.z,
		right.x, top.x, back.x,
		right.y, top.y, back.y,
		right.z, top.z, back.z
	)
end