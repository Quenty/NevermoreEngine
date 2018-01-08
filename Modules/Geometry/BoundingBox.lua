--- Bounding box utilties
-- @classmod BoundingBox

local lib = {}

lib.BOUNDING_BOX_POINTS = {
	{-1,-1,-1};
	{ 1,-1,-1};
	{-1, 1,-1};
	{ 1, 1,-1};
	{-1,-1, 1};
	{ 1,-1, 1};
	{-1, 1, 1};
	{ 1, 1, 1};
}


function lib.GetPartsBoundingBox(parts, relativeTo)
	return lib.GetBoundingBox(parts, relativeTo)
end

--- Gets a boundingBox for the given data
-- @param data List of things with both Size and CFrame
-- @tparam[opt=CFrame.new()] relativeTo
-- @treturn Vector3 Size
-- @treturn CFrame CFrame
function lib.GetBoundingBox(data, relativeTo)
	relativeTo = relativeTo or CFrame.new()
	local sides = {-math.huge; math.huge; -math.huge; math.huge; -math.huge; math.huge}

	for _, data in pairs(data) do
		local size = data.Size
		local rotation = relativeTo:toObjectSpace(data.CFrame)

		local boxPoints = lib.BOUNDING_BOX_POINTS -- Localize for performance
		local rx, ry, rz, R00, R01, R02, R10, R11, R12, R20, R21, R22 = rotation:components()
		local sx, sy, sz = size.x/2, size.y/2, size.z/2

		for i=1, 8 do
			local face = boxPoints[i]
			local sx, sy, sz = sx*face[1], sy*face[2], sz*face[3]
			local x = rx + R00*sx + R01*sy + R02*sz
			local y = ry + R10*sx + R11*sy + R12*sz
			local z = rz + R20*sx + R21*sy + R22*sz

			if x > sides[1] then sides[1] = x end
			if x < sides[2] then sides[2] = x end
			if y > sides[3] then sides[3] = y end
			if y < sides[4] then sides[4] = y end
			if z > sides[5] then sides[5] = z end
			if z < sides[6] then sides[6] = z end
		end
	end

	local size = Vector3.new(sides[1]-sides[2], sides[3]-sides[4], sides[5]-sides[6])
	local cframe = relativeTo:toWorldSpace(CFrame.new((sides[1]+sides[2])/2, (sides[3]+sides[4])/2, (sides[5]+sides[6])/2))

	return size, cframe
end

return lib