--!nonstrict
--[=[
	@class RoguePropertyBaseValueTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyBaseValueTypes = require("RoguePropertyBaseValueTypes")

local RoguePropertyBaseValueTypeUtils = {}

function RoguePropertyBaseValueTypeUtils.isRoguePropertyBaseValueType(value)
	return value == RoguePropertyBaseValueTypes.INSTANCE or value == RoguePropertyBaseValueTypes.ANY
end

return RoguePropertyBaseValueTypeUtils
