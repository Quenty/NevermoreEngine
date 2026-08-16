--!nonstrict
--[=[
	@class random
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(min: number?, max: number?, dis: any?, seed: number?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		if hookState.randomNumber == nil then
			local rng = Random.new(seed)
			hookState.randomNumber = rng:NextNumber(min or 0, max or 1)
		end
		return hookState.randomNumber
	end
end
