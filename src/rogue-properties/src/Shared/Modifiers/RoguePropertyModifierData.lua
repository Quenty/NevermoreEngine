--[=[
	@class RoguePropertyModifierData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")
local ValueBaseValue = require("ValueBaseValue")
local t = require("t")

return AdorneeData.new({
	Order = 0;
	RoguePropertySourceLink = AdorneeDataEntry.new(t.optional(t.Instance), function(adornee)
		return ValueBaseValue.new(adornee, "ObjectValue", "RoguePropertySourceLink", nil)
	end);
})