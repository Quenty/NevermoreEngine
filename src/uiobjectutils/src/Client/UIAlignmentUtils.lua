--[=[
	Utility methods for working with horizontal and vertical alignment
	@class UIAlignmentUtils
]=]

local UIAlignmentUtils = {}

--[=[
	Converts alignment to a number from 0 to 1

	@param horizontalAlignment HorizontalAlignment
	@return number
]=]
function UIAlignmentUtils.horizontalAlignmentToNumber(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	if horizontalAlignment == Enum.HorizontalAlignment.Left then
		return 0
	elseif horizontalAlignment == Enum.HorizontalAlignment.Center then
		return 0.5
	elseif horizontalAlignment == Enum.HorizontalAlignment.Right then
		return 1
	else
		error(("[UIAlignmentUtils] - Bad horizontalAlignment %q"):format(tostring(horizontalAlignment)))
	end
end

--[=[
	Converts alignment to a number from -1 to 1

	@param horizontalAlignment HorizontalAlignment
	@return number
]=]
function UIAlignmentUtils.horizontalAlignmentToBias(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	if horizontalAlignment == Enum.HorizontalAlignment.Left then
		return -1
	elseif horizontalAlignment == Enum.HorizontalAlignment.Center then
		return 0
	elseif horizontalAlignment == Enum.HorizontalAlignment.Right then
		return 1
	else
		error(("[UIAlignmentUtils] - Bad horizontalAlignment %q"):format(tostring(horizontalAlignment)))
	end
end

--[=[
	Converts alignment to a number from 0 to 1

	@param verticalAlignment VerticalAlignment
	@return number
]=]
function UIAlignmentUtils.verticalAlignmentToNumber(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")

	if verticalAlignment == Enum.VerticalAlignment.Top then
		return 0
	elseif verticalAlignment == Enum.VerticalAlignment.Center then
		return 0.5
	elseif verticalAlignment == Enum.VerticalAlignment.Bottom then
		return 1
	else
		error(("[UIAlignmentUtils] - Bad verticalAlignment %q"):format(tostring(verticalAlignment)))
	end
end

--[=[
	Converts alignment to a number from -1 to 1

	@param verticalAlignment VerticalAlignment
	@return number
]=]
function UIAlignmentUtils.verticalAlignmentToBias(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")

	if verticalAlignment == Enum.VerticalAlignment.Top then
		return -1
	elseif verticalAlignment == Enum.VerticalAlignment.Center then
		return 0
	elseif verticalAlignment == Enum.VerticalAlignment.Bottom then
		return 1
	else
		error(("[UIAlignmentUtils] - Bad verticalAlignment %q"):format(tostring(verticalAlignment)))
	end
end

return UIAlignmentUtils