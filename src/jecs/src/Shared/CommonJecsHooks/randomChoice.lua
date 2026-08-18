--!nonstrict
--[=[
	@class randomChoice

	Give it a dictionary:
	key = any value,
	value = number weight
	will choose based on weights,
	can choose to be persistent or pass in a clock() to dis
	if you pass in something like callbacks, do noCache to avoid closing callbacks
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local RandomUtils = require("RandomUtils")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(choices: { [any]: number }, dis: any?, alwaysRandom: boolean?, noCache: boolean?, rng: Random?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		if not hookState.init then
			hookState.init = true
			hookState.arrayOfValues = {}
			hookState.arrayOfWeights = {}
			for value, weight in choices do
				table.insert(hookState.arrayOfValues, value)
				table.insert(hookState.arrayOfWeights, weight)
			end
			hookState.chosen = RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
			_hookMaid:GiveTask(function()
				table.clear(hookState)
			end)
		end
		if noCache then
			if alwaysRandom == true then
				hookState.arrayOfValues = {}
				hookState.arrayOfWeights = {}
				for value, weight in choices do
					table.insert(hookState.arrayOfValues, value)
					table.insert(hookState.arrayOfWeights, weight)
				end
				hookState.chosen = RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
			end
		else
			if alwaysRandom == true then
				hookState.chosen = RandomUtils.weightedChoice(hookState.arrayOfValues, hookState.arrayOfWeights, rng)
			end
		end
		return hookState.chosen
	end
end
