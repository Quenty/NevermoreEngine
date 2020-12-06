---
-- @module TextServiceUtils
-- @author Quenty

local TextService = game:GetService("TextService")

local TextServiceUtils = {}

function TextServiceUtils.getSizeForLabel(textLabel, text)
	assert(typeof(textLabel) == "Instance")
	assert(type(text) == "string")

	return TextService:GetTextSize(text, textLabel.TextSize, textLabel.Font, Vector2.new(1e6, 1e6))
end

return TextServiceUtils