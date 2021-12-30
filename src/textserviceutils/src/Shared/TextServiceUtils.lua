--[=[
	@class TextServiceUtils
]=]

local TextService = game:GetService("TextService")

local require = require(script.Parent.loader).load(script)

local Blend = require("Blend")

local TextServiceUtils = {}

function TextServiceUtils.getSizeForLabel(textLabel, text, maxWidth)
	assert(typeof(textLabel) == "Instance", "Bad textLabel")
	assert(type(text) == "string", "Bad text")

	maxWidth = maxWidth or 1e6
	assert(maxWidth > 0, "Bad maxWidth")

	return TextService:GetTextSize(text, textLabel.TextSize, textLabel.Font, Vector2.new(maxWidth, 1e6))
end

function TextServiceUtils.observeSizeForLabelProps(props)
	assert(props.Text, "Bad props.Text")
	assert(props.TextSize, "Bad props.TextSize")
	assert(props.Font, "Bad props.Font")

	return Blend.Computed(props.Text, props.TextSize, props.Font, props.MaxSize or Vector2.new(1e6, 1e6),
		function(text, textSize, font, maxSize)
			return TextService:GetTextSize(text, textSize, font, maxSize)
		end)
end

return TextServiceUtils