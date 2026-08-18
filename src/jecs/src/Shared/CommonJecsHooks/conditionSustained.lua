--!nonstrict
--[=[
	@class conditionSustained

	Seconds the condition has been continuously true. Resets when false or when
	this hook is not invoked for a frame (evaluateAndCleanupHooks).
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(condition: boolean, dis: any?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if not condition then
			hookState.lastSatisfiedClock = nil
			return 0
		end

		local now = os.clock()
		if not hookState.lastSatisfiedClock then
			hookState.lastSatisfiedClock = now
			return 0
		end

		return now - hookState.lastSatisfiedClock
	end
end
