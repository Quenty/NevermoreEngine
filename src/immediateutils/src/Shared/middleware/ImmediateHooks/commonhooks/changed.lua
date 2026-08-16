--!nonstrict
--[=[
	@class changed

	Returns true if the value has changed since the last call.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(value: any, dis: any?, runFirst: boolean?, onlyOnEqualTo: any?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		if hookState.lastValue == nil then
			hookState.lastValue = value
			if onlyOnEqualTo ~= nil then
				return value == onlyOnEqualTo
			end
			if runFirst == true then
				return true
			end
			return false
		end

		if hookState.lastValue ~= value then
			hookState.lastValue = value
			if onlyOnEqualTo ~= nil then
				return value == onlyOnEqualTo
			else
				return true
			end
		end

		return false
	end
end
