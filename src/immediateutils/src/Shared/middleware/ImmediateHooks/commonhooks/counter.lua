--!nonstrict
--[=[
	@class counter

	Every time it is called it counts up.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		hookState.counter = (hookState.counter or 0) + 1
		return hookState.counter
	end
end
