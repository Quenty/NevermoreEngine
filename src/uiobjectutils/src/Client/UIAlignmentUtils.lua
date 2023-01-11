--[=[
	@class UIAlignmentUtils
]=]

local require = require(script.Parent.loader).load(script)

local UIAlignmentUtils = {}

function UIAlignmentUtils.horizontalAlignmentToNumber(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	local x
	if horizontalAlignment == Enum.HorizontalAlignment.Left then
		x = 0
	elseif horizontalAlignment == Enum.HorizontalAlignment.Center then
		x = 0.5
	elseif horizontalAlignment == Enum.HorizontalAlignment.Right then
		x = 1
	else
		error(("[UIAlignmentUtils] - Bad horizontalAlignment %q"):format(tostring(horizontalAlignment)))
	end

	return x
end

function UIAlignmentUtils.verticalAlignmentToNumber(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")
	local y
	if verticalAlignment == Enum.VerticalAlignment.Top then
		y = 0
	elseif verticalAlignment == Enum.VerticalAlignment.Center then
		y = 0.5
	elseif verticalAlignment == Enum.VerticalAlignment.Bottom then
		y = 1
	else
		error(("[UIAlignmentUtils] - Bad verticalAlignment %q"):format(tostring(verticalAlignment)))
	end
	return y
end

return UIAlignmentUtils