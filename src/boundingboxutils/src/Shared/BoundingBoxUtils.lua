--[=[
	Bounding box utilties. Prefer model:GetBoundingBox() in most cases. However, sometimes grouping isn't possible.
	@class BoundingBoxUtils
]=]

local BoundingBoxUtils = {}

--[=[
	Retrieves a bounding box for a given set of parts

	@param parts { Instance | { { CFrame: CFrame, Size: Vector3 } }
	@param relativeTo CFrame?
	@return Vector3 -- size
	@return Vector3 -- position
]=]
function BoundingBoxUtils.getPartsBoundingBox(parts, relativeTo)
	return BoundingBoxUtils.getBoundingBox(parts, relativeTo)
end

--[=[
	Clamps a point inside of a given bounding box

	See: https://devforum.roblox.com/t/finding-the-closest-vector3-point-on-a-part-from-the-character/130679/2

	@param cframe CFrame -- CFrame of bounding box
	@param size Vector3 -- Size of bounding box
	@param point Vector3 -- Point to transform
	@return Vector3 -- Clamped point
	@return Vector3 -- Center of bounding box
]=]
function BoundingBoxUtils.clampPointToBoundingBox(cframe, size, point)
	local transform = cframe:PointToObjectSpace(point) -- transform into local space
	local halfSize = size * 0.5
	return cframe * Vector3.new( -- Clamp & transform into world space
		math.clamp(transform.x, -halfSize.x, halfSize.x),
		math.clamp(transform.y, -halfSize.y, halfSize.y),
		math.clamp(transform.z, -halfSize.z, halfSize.z)
	), cframe.Position
end

--[=[
	Pushes a point to lie within the bounding box

	@param cframe CFrame -- CFrame of bounding box
	@param size Vector3 -- Size of bounding box
	@param point Vector3 -- Point to transform
	@return Vector3
]=]
function BoundingBoxUtils.pushPointToLieOnBoundingBox(cframe, size, point)
	local transform = cframe:PointToObjectSpace(point) -- transform into local space
	local halfSize = size * 0.5
	local x = transform.x < 0 and -halfSize.x or halfSize.x
	local y = transform.y < 0 and -halfSize.y or halfSize.y
	local z = transform.z < 0 and -halfSize.z or halfSize.z
	return cframe * Vector3.new(x, y, z), cframe.Position
end

--[=[
	Given a parent, retrieve the bounding box for this parent

	@param parent Instance
	@param relativeTo CFrame?
	@return Vector3? -- size
	@return Vector3? -- position
]=]
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

--[=[
	Returns the size of an axis aligned bounding box for a given CFrame

	@param cframe CFrame
	@param size Vector3
]=]
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


--[=[
	Gets a boundingBox for the given data.

	See: https://gist.github.com/zeux/1a67e8930df782d5474276e218831e22

	@param data Instance | { { CFrame: CFrame; Size: Vector3 } -- List of things with both Size and CFrame
	@param relativeTo CFrame?
	@return Vector3 -- size
	@return Vector3 -- position
]=]
function BoundingBoxUtils.getBoundingBox(data, relativeTo: CFrame?)
	relativeTo = relativeTo or CFrame.new()

	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge

	for _, obj in pairs(data) do
		local cframe = relativeTo:toObjectSpace(obj.CFrame)
		local size = obj.Size
		local sx, sy, sz = size.X, size.Y, size.Z

		local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cframe:GetComponents()

		-- https://zeuxcg.org/2010/10/17/aabb-from-obb-with-component-wise-abs/
		local wsx = 0.5 * (math.abs(R00) * sx + math.abs(R01) * sy + math.abs(R02) * sz)
		local wsy = 0.5 * (math.abs(R10) * sx + math.abs(R11) * sy + math.abs(R12) * sz)
		local wsz = 0.5 * (math.abs(R20) * sx + math.abs(R21) * sy + math.abs(R22) * sz)

		if minx > x - wsx then
			minx = x - wsx
		end
		if miny > y - wsy then
			miny = y - wsy
		end
		if minz > z - wsz then
			minz = z - wsz
		end

		if maxx < x + wsx then
			maxx = x + wsx
		end
		if maxy < y + wsy then
			maxy = y + wsy
		end
		if maxz < z + wsz then
			maxz = z + wsz
		end
	end

	local size = Vector3.new(maxx-minx, maxy-miny, maxz-minz)
	local position = Vector3.new((maxx + minx)/2, (maxy+miny)/2, (maxz+minz)/2)
	return size, position
end

--[=[
	Returns if a point is in a bounding box

	@param cframe CFrame
	@param size Vector3
	@param testPosition Vector3
	@return boolean
]=]
function BoundingBoxUtils.inBoundingBox(cframe: CFrame, size: Vector3, testPosition: Vector3): boolean
	local relative = cframe:PointToObjectSpace(testPosition)
	local hsx, hsy, hsz = size.X/2, size.Y/2, size.Z/2

	local rx, ry, rz = relative.x, relative.y, relative.z
	return rx >= -hsx
		and rx <= hsx
		and ry >= -hsy
		and ry <= hsy
		and rz >= -hsz
		and rz <= hsz
end

--[=[
	Returns if a point is in a bounding box defined by a Roblox part with the Cylinder shape.

	@param cframe CFrame
	@param size Vector3
	@param testPosition Vector3
	@return boolean
]=]
function BoundingBoxUtils.inCylinderBoundingBox(cframe, size, testPosition)
	local relative = cframe:PointToObjectSpace(testPosition)
	local half_height = size.x/2
	local radius = math.min(size.y, size.z)/2

	local rx, ry, rz = relative.x, relative.y, relative.z
	local dist = ry*ry + rz*rz
	return math.abs(rx) <= half_height
		and dist <= (radius*radius)
end

--[=[
	Returns if a point is in a bounding box defined by a Roblox part with the ball shape.

	@param cframe CFrame
	@param size Vector3
	@param testPosition Vector3
	@return boolean
]=]
function BoundingBoxUtils.inBallBoundingBox(cframe, size, testPosition)
	local relative = cframe:PointToObjectSpace(testPosition)
	local radius = math.min(size.x, size.y, size.z)/2

	local rx, ry, rz = relative.x, relative.y, relative.z
	local dist = rx*rx + ry*ry + rz*rz
	return dist <= radius*radius
end

return BoundingBoxUtils