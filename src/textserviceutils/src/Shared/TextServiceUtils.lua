---
-- @module TextServiceUtils
-- @author Quenty

local TextService = game:GetService("TextService")

local TextServiceUtils = {}

function TextServiceUtils.getSizeForLabel(textLabel, text, maxWidth)
	assert(typeof(textLabel) == "Instance", "Bad textLabel")
	assert(type(text) == "string", "Bad text")

	maxWidth = maxWidth or 1e6
	assert(maxWidth > 0, "Bad maxWidth")

	return TextService:GetTextSize(text, textLabel.TextSize, textLabel.Font, Vector2.new(maxWidth, 1e6))
end

return TextServiceUtils