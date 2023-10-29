--[=[
	@class ScrollingDirectionUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

local ScrollingDirectionUtils = {}

function ScrollingDirectionUtils.canScrollHorizontal(scrollingDirection)
	assert(EnumUtils.isOfType(Enum.ScrollingDirection, scrollingDirection))

	return scrollingDirection == Enum.ScrollingDirection.X or scrollingDirection == Enum.ScrollingDirection.XY
end

function ScrollingDirectionUtils.canScrollVertical(scrollingDirection)
	assert(EnumUtils.isOfType(Enum.ScrollingDirection, scrollingDirection))

	return scrollingDirection == Enum.ScrollingDirection.Y or scrollingDirection == Enum.ScrollingDirection.XY
end

return ScrollingDirectionUtils