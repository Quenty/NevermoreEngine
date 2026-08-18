--!nonstrict
--[=[
	@class delta

	Kinda like deltaTime and changed: pass in a value (should be of same type) and it
	returns the difference between the last call and the current call.

	Pass conditionToEvaluate = false for a no-op: returns zero and does not update
	the stored value, so the next evaluated call still diffs against the last included sample.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateHookUtils = require("JecsImmediateHookUtils")
local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(
		value: JecsImmediateHookUtils.AverageableValue,
		dis: any?,
		conditionToEvaluate: boolean?
	): JecsImmediateHookUtils.AverageableValue
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if conditionToEvaluate == false then
			if hookState.lastValue then
				return value - hookState.lastValue
			else
				return JecsImmediateHookUtils.zeroSum(value)
			end
		end

		local lastValue = hookState.lastValue
		hookState.lastValue = value
		if lastValue == nil then
			return JecsImmediateHookUtils.zeroSum(value)
		end
		return (value :: any) - lastValue, lastValue
	end
end
