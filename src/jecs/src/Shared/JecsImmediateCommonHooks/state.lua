--!nonstrict
--[=[
	@class state
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local Maid = require("Maid")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
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
