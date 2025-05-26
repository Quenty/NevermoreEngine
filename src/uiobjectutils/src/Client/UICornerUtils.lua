--!strict
--[=[
	@class UICornerUtils
]=]

local UICornerUtils = {}

--[=[
	Creates a new UI corner
	@param scale number
	@param parent Instance
	@return UICorner
]=]
function UICornerUtils.fromScale(scale: number, parent: Instance?): UICorner
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(scale, 0)
	uiCorner.Parent = parent
	return uiCorner
end

--[=[
	Creates a new UI corner from offset
	@param offset number
	@param parent Instance
	@return UICorner
]=]
function UICornerUtils.fromOffset(offset: number, parent: Instance?): UICorner
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, offset)
	uiCorner.Parent = parent
	return uiCorner
end

-- framePosition is top left corner
--[=[
	Clamps a position to a frame with a rounded corner

	@param framePosition Vector2 -- From top left corner
	@param frameSize Vector2
	@param radius number
	@param point Vector2
	@return Vector2? -- Position
	@return Vector2? -- Normal
]=]
function UICornerUtils.clampPositionToFrame(
	framePosition: Vector2,
	frameSize: Vector2,
	radius: number,
	point: Vector2
): (Vector2?, Vector2?)
	assert(radius >= 0, "Bad radius")
	assert(point, "Bad point")

	local px, py = point.X, point.Y

	local fpx, fpy = framePosition.X, framePosition.Y
	local fsx, fsy = frameSize.X, frameSize.Y

	local minx = fpx + radius
	local maxx = fpx + fsx - radius

	local miny = fpy + radius
	local maxy = fpy + fsy - radius

	-- relative position to inner box
	local rpx, rpy

	if minx < maxx then
		rpx = math.clamp(px, minx, maxx)
	else
		rpx = minx
	end

	if miny < maxy then
		rpy = math.clamp(py, miny, maxy)
	else
		rpy = miny
	end

	local position = Vector2.new(rpx, rpy)

	-- project in direction of offset
	local direction = point - position
	if direction.Magnitude == 0 then
		-- Shouldn't happen!
		return nil, nil
	end

	local normal = direction.Unit
	local outsidePosition = position + normal * radius
	return outsidePosition, normal
end

return UICornerUtils
