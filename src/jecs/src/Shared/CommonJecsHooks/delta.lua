--!nonstrict
--[=[
	@class delta

	Kinda like deltaTime and changed: pass in a value (should be of same type) and it
	returns the difference between the last call and the current call.

	Pass conditionToEvaluate = false for a no-op: returns zero and does not update
	the stored value, so the next evaluated call still diffs against the last included sample.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateHookAverageUtils = require("ImmediateHookAverageUtils")
local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(
		value: ImmediateHookAverageUtils.AverageableValue,
		dis: any?,
		conditionToEvaluate: boolean?
	): ImmediateHookAverageUtils.AverageableValue
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if conditionToEvaluate == false then
			if hookState.lastValue then
				return value - hookState.lastValue
			else
				return ImmediateHookAverageUtils.zeroSum(value)
			end
		end

		local lastValue = hookState.lastValue
		hookState.lastValue = value
		if lastValue == nil then
			return ImmediateHookAverageUtils.zeroSum(value)
		end
		return (value :: any) - lastValue, lastValue
	end
end
