--!strict
--[=[
	@class RoguePropertyModifierData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")
local ValueBaseValue = require("ValueBaseValue")
local t: any = require("t") -- t isn't strict-friendly

return AdorneeData.new({
	Enabled = true,
	Order = 0,
	RoguePropertySourceLink = AdorneeDataEntry.new(t.optional(t.Instance), function(adornee: Instance)
		return ValueBaseValue.new(adornee, "ObjectValue", "RoguePropertySourceLink", nil)
	end),
})
