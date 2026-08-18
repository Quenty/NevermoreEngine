--!strict
--[=[
	@class gate

	Like once, but cleans up if not in the hot path anymore, and will be able to
	return true if reached again.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		if hookState.ran then
			return false
		end
		hookState.ran = true
		return true
	end :: (any) -> boolean
end
