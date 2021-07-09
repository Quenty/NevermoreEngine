--- Bounding box utilties. Prefer model:GetBoundingBox() in most cases. However, sometimes grouping isn't possible.
-- @module BoundingBoxUtils

local BoundingBoxUtils = {}

function BoundingBoxUtils.getPartsBoundingBox(parts, relativeTo)
	return BoundingBoxUtils.getBoundingBox(parts, relativeTo)
end

-- https://devforum.roblox.com/t/finding-the-closest-vector3-point-on-a-part-from-the-character/130679/2
function BoundingBoxUtils.clampPointToBoundingBox(cframe, size, point)
	local transform = cframe:pointToObjectSpace(point) -- transform into local space
	local halfSize = size * 0.5
	return cframe * Vector3.new( -- Clamp & transform into world space
		math.clamp(transform.x, -halfSize.x, halfSize.x),
		math.clamp(transform.y, -halfSize.y, halfSize.y),
		math.clamp(transform.z, -halfSize.z, halfSize.z)
	), cframe.p
end

function BoundingBoxUtils.pushPointToLieOnBoundingBox(cframe, size, point)
	local transform = cframe:pointToObjectSpace(point) -- transform into local space
	local halfSize = size * 0.5
	local x = transform.x < 0 and -halfSize.x or halfSize.x
	local y = transform.y < 0 and -halfSize.y or halfSize.y
	local z = transform.z < 0 and -halfSize.z or halfSize.z
	return cframe * Vector3.new(x, y, z), cframe.p
end

-- @return size, position
function BoundingBoxUtils.getChildrenBoundingBox(parent, relativeTo)
	local parts = {}
	for _, item in pairs(parent:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end

	if not next(parts) then
		return nil, nil
	end

	return BoundingBoxUtils.getPartsBoundingBox(parts, relativeTo)
end

function BoundingBoxUtils.axisAlignedBoxSize(cframe, size)
	local inv = cframe:inverse()

	local wx = size*inv.XVector
	local wy = size*inv.YVector
	local wz = size*inv.ZVector

	return Vector3.new(
		math.abs(wx.x) + math.abs(wx.y) + math.abs(wx.z),
		math.abs(wy.x) + math.abs(wy.y) + math.abs(wy.z),
		math.abs(wz.x) + math.abs(wz.y) + math.abs(wz.z)
	)
end


--- Gets a boundingBox for the given data
-- @param data List of things with both Size and CFrame
-- @tparam[opt=CFrame.new()] relativeTo
-- @treturn Vector3 Size
-- @treturn Position position
-- https://gist.github.com/zeux/1a67e8930df782d5474276e218831e22
function BoundingBoxUtils.getBoundingBox(data, relativeTo)
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

function BoundingBoxUtils.inBoundingBox(cframe, size, testPosition)
	local relative = cframe:pointToObjectSpace(testPosition)
	local hsx, hsy, hsz = size.X/2, size.Y/2, size.Z/2

	local rx, ry, rz = relative.x, relative.y, relative.z
	return rx >= -hsx
		and rx <= hsx
		and ry >= -hsy
		and ry <= hsy
		and rz >= -hsz
		and rz <= hsz
end

return BoundingBoxUtils