--!nonstrict
--[=[
	@class state
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Maid = require("Maid")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, initFunction: ({ any? }, Maid.Maid) -> ...any?)
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		if hookState._init == nil then
			hookState._init = true
			if initFunction then
				initFunction(hookState, hookMaid)
			end
		end
		return hookState, hookMaid
	end
end
