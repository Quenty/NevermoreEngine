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

function lib.GetModelBoundingBox(model)
	local parts = {}
	for _, item in pairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return lib.GetPartsBoundingBox(parts)
end


--- Gets a boundingBox for the given data
-- @param data List of things with both Size and CFrame
-- @tparam[opt=CFrame.new()] relativeTo
-- @treturn Vector3 Size
-- @treturn CFrame CFrame
-- function lib.GetBoundingBox(data, relativeTo)
-- 	relativeTo = relativeTo or CFrame.new()
-- 	local sides = {-math.huge; math.huge; -math.huge; math.huge; -math.huge; math.huge}

-- 	for _, data in pairs(data) do
-- 		local size = data.Size
-- 		local rotation = relativeTo:toObjectSpace(data.CFrame)

-- 		local boxPoints = lib.BOUNDING_BOX_POINTS -- Localize for performance
-- 		local rx, ry, rz, R00, R01, R02, R10, R11, R12, R20, R21, R22 = rotation:components()
-- 		local sx, sy, sz = size.x/2, size.y/2, size.z/2

-- 		for i=1, 8 do
-- 			local face = boxPoints[i]
-- 			local sx, sy, sz = sx*face[1], sy*face[2], sz*face[3]
-- 			local x = rx + R00*sx + R01*sy + R02*sz
-- 			local y = ry + R10*sx + R11*sy + R12*sz
-- 			local z = rz + R20*sx + R21*sy + R22*sz

-- 			if x > sides[1] then sides[1] = x end
-- 			if x < sides[2] then sides[2] = x end
-- 			if y > sides[3] then sides[3] = y end
-- 			if y < sides[4] then sides[4] = y end
-- 			if z > sides[5] then sides[5] = z end
-- 			if z < sides[6] then sides[6] = z end
-- 		end
-- 	end

-- 	local size = Vector3.new(sides[1]-sides[2], sides[3]-sides[4], sides[5]-sides[6])
-- 	local cframe = CFrame.new((sides[1]+sides[2])/2, (sides[3]+sides[4])/2, (sides[5]+sides[6])/2)

-- 	return size, cframe
-- end

--- Gets a boundingBox for the given data
-- @param data List of things with both Size and CFrame
-- @tparam[opt=CFrame.new()] relativeTo
-- @treturn Vector3 Size
-- @treturn Position position
-- https://gist.github.com/zeux/1a67e8930df782d5474276e218831e22
function lib.GetBoundingBox(data, relativeTo)
	relativeTo = relativeTo or CFrame.new()
	local abs = math.abs
	local inf = math.huge

	local minx, miny, minz = inf, inf, inf
	local maxx, maxy, maxz = -inf, -inf, -inf

	for _, obj in pairs(data) do
		local cf = relativeTo:toObjectSpace(obj.CFrame)
		local size = obj.Size
		local sx, sy, sz = size.X, size.Y, size.Z

		local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:components()

		-- https://zeuxcg.org/2010/10/17/aabb-from-obb-with-component-wise-abs/
		local wsx = 0.5 * (abs(R00) * sx + abs(R01) * sy + abs(R02) * sz)
		local wsy = 0.5 * (abs(R10) * sx + abs(R11) * sy + abs(R12) * sz)
		local wsz = 0.5 * (abs(R20) * sx + abs(R21) * sy + abs(R22) * sz)

		if minx > x - wsx then minx = x - wsx end
		if miny > y - wsy then miny = y - wsy end
		if minz > z - wsz then minz = z - wsz end

		if maxx < x + wsx then maxx = x + wsx end
		if maxy < y + wsy then maxy = y + wsy end
		if maxz < z + wsz then maxz = z + wsz end
	end

	local size = Vector3.new(maxx-minx, maxy-miny, maxz-minz)
	local position = Vector3.new((maxx + minx)/2, (maxy+miny)/2, (maxz+minz)/2)
	return size, position
end

return lib