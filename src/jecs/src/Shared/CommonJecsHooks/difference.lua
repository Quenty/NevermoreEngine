--!nonstrict
--[=[
	@class difference

	Like changed but you need to pass in a number value.
	Will return the difference between the last call and the current call.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(currentNumber: number, dis: any?, flagToUpdate: boolean?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if hookState.lastNumber == nil then
			hookState.lastNumber = currentNumber
			return 0
		end

		local difference = currentNumber - hookState.lastNumber

		if flagToUpdate == nil or flagToUpdate == true then
			hookState.lastNumber = currentNumber
		end

		return difference
	end
end
