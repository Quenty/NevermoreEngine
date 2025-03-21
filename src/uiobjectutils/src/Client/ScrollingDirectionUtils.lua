--!strict
--[=[
	Utility logic involving scrolling direction

	@class ScrollingDirectionUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

local ScrollingDirectionUtils = {}

--[=[
	Determines if the scrolling direction can scroll horizontally
]=]
function ScrollingDirectionUtils.canScrollHorizontal(scrollingDirection: Enum.ScrollingDirection): boolean
	assert(EnumUtils.isOfType(Enum.ScrollingDirection, scrollingDirection))

	return scrollingDirection == Enum.ScrollingDirection.X or scrollingDirection == Enum.ScrollingDirection.XY
end

--[=[
	Determines if the scrolling direction can scroll vertically
]=]
function ScrollingDirectionUtils.canScrollVertical(scrollingDirection: Enum.ScrollingDirection): boolean
	assert(EnumUtils.isOfType(Enum.ScrollingDirection, scrollingDirection))

	return scrollingDirection == Enum.ScrollingDirection.Y or scrollingDirection == Enum.ScrollingDirection.XY
end

return ScrollingDirectionUtils
