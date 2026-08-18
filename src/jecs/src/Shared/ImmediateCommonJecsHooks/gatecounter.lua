--!nonstrict
--[=[
	@class gatecounter

	A stable discriminator epoch for code paths that run every frame while "active".
	Starts at 1. Returns the same number for every call in a continuous run; after at
	least one frame without a call (evaluateAndCleanupHooks), the epoch increments so
	the next run can use a fresh discriminator for cache/subscribe/etc.

	Careful, because this needs to store counter as state no matter if it's called or not,
	so this may leak.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis, function(state)
			if state._activeThisFrame then
				state._onHotPath = true
				state._activeThisFrame = nil
			elseif state._onHotPath then
				state.counter = (state.counter or 1) + 1
				state._onHotPath = false
			end
			return false
		end)
		if hookState.counter == nil then
			hookState.counter = 1
		end
		hookState._activeThisFrame = true
		return hookState.counter
	end
end
