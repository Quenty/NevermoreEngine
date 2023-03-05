--[=[
	@class TransitionUtils
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")

local TransitionUtils = {}

function TransitionUtils.isTransition(value)
	return BasicPane.isBasicPane(value)
		and type(value.PromiseShow) == "function"
		and type(value.PromiseHide) == "function"
		and type(value.PromiseToggle) == "function"
end

return TransitionUtils