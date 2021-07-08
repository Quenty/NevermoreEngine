---
-- @module TextServiceUtils
-- @author Quenty

local TextService = game:GetService("TextService")

local TextServiceUtils = {}

function TextServiceUtils.getSizeForLabel(textLabel, text, maxWidth)
	assert(typeof(textLabel) == "Instance")
	assert(type(text) == "string")

	maxWidth = maxWidth or 1e6
	assert(maxWidth > 0)

	return TextService:GetTextSize(text, textLabel.TextSize, textLabel.Font, Vector2.new(maxWidth, 1e6))
end

return TextServiceUtils