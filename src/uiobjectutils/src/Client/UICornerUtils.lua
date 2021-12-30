--[=[
	@class UICornerUtils
]=]

local UICornerUtils = {}

function UICornerUtils.fromScale(scale, parent)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(scale, 0)
	uiCorner.Parent = parent
	return uiCorner
end

function UICornerUtils.fromOffset(offset, parent)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, offset)
	uiCorner.Parent = parent
	return uiCorner
end

-- framePosition is top left corner
-- returns position, relativePosition, normal
function UICornerUtils.clampPositionToFrame(framePosition, frameSize, radius, point)
	assert(radius > 0, "Bad radius")
	assert(point, "Bad point")

	local px, py = point.x, point.y

	local fpx, fpy = framePosition.x, framePosition.y
	local fsx, fsy = frameSize.x, frameSize.y

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
	if direction.magnitude == 0 then
		-- Shouldn't happen!
		return nil, nil
	end

	local normal = direction.unit
	local outsidePosition = position + normal*radius
	return outsidePosition, normal
end

return UICornerUtils