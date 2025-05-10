--!strict
--[=[
	@class TransitionUtils
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")

local TransitionUtils = {}

--[=[
	Returns true if the value is a transition, that is, it implements the following
	methods:

	* PromiseShow
	* PromiseHide
	* PromiseToggle

	@param value any
	@return boolean
]=]
function TransitionUtils.isTransition(value: any): boolean
	return BasicPane.isBasicPane(value)
		and type(value.PromiseShow) == "function"
		and type(value.PromiseHide) == "function"
		and type(value.PromiseToggle) == "function"
end

return TransitionUtils
