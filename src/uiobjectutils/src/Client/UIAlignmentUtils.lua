--[=[
	Utility methods for working with horizontal and vertical alignment
	@class UIAlignmentUtils
]=]

local UIAlignmentUtils = {}

local HORIZONTAL_ALIGNMENT = {
	[Enum.HorizontalAlignment.Left] = 0;
	[Enum.HorizontalAlignment.Center] = 0.5;
	[Enum.HorizontalAlignment.Right] = 1;
}

local HORIZONTAL_BIAS = {
	[Enum.HorizontalAlignment.Left] = -1;
	[Enum.HorizontalAlignment.Center] = 0;
	[Enum.HorizontalAlignment.Right] = 1;
}

local VERTICAL_ALIGNMENT = {
	[Enum.VerticalAlignment.Top] = 0;
	[Enum.VerticalAlignment.Center] = 0.5;
	[Enum.VerticalAlignment.Bottom] = 1;
}

local VERTICAL_BIAS = {
	[Enum.VerticalAlignment.Top] = -1;
	[Enum.VerticalAlignment.Center] = 0;
	[Enum.VerticalAlignment.Bottom] = 1;
}

local VERTICAL_TO_HORIZONTAL = {
	[Enum.VerticalAlignment.Top] = Enum.HorizontalAlignment.Left;
	[Enum.VerticalAlignment.Center] = Enum.HorizontalAlignment.Center;
	[Enum.VerticalAlignment.Bottom] = Enum.HorizontalAlignment.Right;
}

local HORIZONTAL_TO_VERTICAL = {
	[Enum.HorizontalAlignment.Left] = Enum.VerticalAlignment.Top;
	[Enum.HorizontalAlignment.Center] = Enum.VerticalAlignment.Center;
	[Enum.HorizontalAlignment.Right] = Enum.VerticalAlignment.Bottom;
}

--[=[
	Converts alignment to 0, 0.5 or 1

	@param alignment HorizontalAlignment | VertialAlignment
	@return number
]=]
function UIAlignmentUtils.toNumber(alignment)
	assert(alignment, "Bad alignment")

	if HORIZONTAL_ALIGNMENT[alignment] then
		return HORIZONTAL_ALIGNMENT[alignment]
	elseif VERTICAL_ALIGNMENT[alignment] then
		return VERTICAL_ALIGNMENT[alignment]
	else
		error(string.format("[UIAlignmentUtils.toNumber] - Bad alignment %q", tostring(alignment)))
	end
end

--[=[
	Converts the HorizontalAlignment to a HorizontalAlignment
	@param verticalAlignment HorizontalAlignment
	@return HorizontalAlignment
]=]
function UIAlignmentUtils.verticalToHorizontalAlignment(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")

	local found = VERTICAL_TO_HORIZONTAL[verticalAlignment]
	if not found then
		error(string.format("[UIAlignmentUtils.verticalToHorizontalAlignment] - Bad verticalAlignment %q", tostring(verticalAlignment)))
	end
	return found
end

--[=[
	Converts the HorizontalAlignment to a VertialAlignment
	@param horizontalAlignment HorizontalAlignment
	@return VertialAlignment
]=]
function UIAlignmentUtils.horizontalToVerticalAlignment(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	local found = HORIZONTAL_TO_VERTICAL[horizontalAlignment]
	if not found then
		error(string.format("[UIAlignmentUtils.horizontalToVerticalAlignment] - Bad horizontalAlignment %q", tostring(horizontalAlignment)))
	end
	return found
end


--[=[
	Converts alignment to bias, as -1, 0, or 1

	@param alignment HorizontalAlignment | VertialAlignment
	@return number
]=]
function UIAlignmentUtils.toBias(alignment)
	assert(alignment, "Bad alignment")

	if HORIZONTAL_BIAS[alignment] then
		return HORIZONTAL_BIAS[alignment]
	elseif VERTICAL_BIAS[alignment] then
		return VERTICAL_BIAS[alignment]
	else
		error(string.format("[UIAlignmentUtils.toBias] - Bad alignment %q", tostring(alignment)))
	end
end

--[=[
	Converts alignment to a number from 0 to 1

	@param horizontalAlignment HorizontalAlignment
	@return number
]=]
function UIAlignmentUtils.horizontalAlignmentToNumber(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	if HORIZONTAL_ALIGNMENT[horizontalAlignment] then
		return HORIZONTAL_ALIGNMENT[horizontalAlignment]
	else
		error(string.format("[UIAlignmentUtils] - Bad horizontalAlignment %q", tostring(horizontalAlignment)))
	end
end

--[=[
	Converts alignment to a number from -1 to 1

	@param horizontalAlignment HorizontalAlignment
	@return number
]=]
function UIAlignmentUtils.horizontalAlignmentToBias(horizontalAlignment)
	assert(horizontalAlignment, "Bad horizontalAlignment")

	if HORIZONTAL_BIAS[horizontalAlignment] then
		return HORIZONTAL_BIAS[horizontalAlignment]
	else
		error(string.format("[UIAlignmentUtils] - Bad horizontalAlignment %q", tostring(horizontalAlignment)))
	end
end

--[=[
	Converts alignment to a number from 0 to 1

	@param verticalAlignment VerticalAlignment
	@return number
]=]
function UIAlignmentUtils.verticalAlignmentToNumber(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")

	if VERTICAL_ALIGNMENT[verticalAlignment] then
		return VERTICAL_ALIGNMENT[verticalAlignment]
	else
		error(string.format("[UIAlignmentUtils] - Bad verticalAlignment %q", tostring(verticalAlignment)))
	end
end

--[=[
	Converts alignment to a number from -1 to 1

	@param verticalAlignment VerticalAlignment
	@return number
]=]
function UIAlignmentUtils.verticalAlignmentToBias(verticalAlignment)
	assert(verticalAlignment, "Bad verticalAlignment")

	if VERTICAL_BIAS[verticalAlignment] then
		return VERTICAL_BIAS[verticalAlignment]
	else
		error(string.format("[UIAlignmentUtils] - Bad verticalAlignment %q", tostring(verticalAlignment)))
	end
end

return UIAlignmentUtils