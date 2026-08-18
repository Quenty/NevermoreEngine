--!nonstrict
--[=[
	@class maid
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local Maid = require("Maid")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis: any?, callback: (maid: Maid.Maid) -> any?)
		local _hookState, hookMaid = getOrCreateHookState(rt, dis, function(_state)
			if callback then
				callback(_state.hookMaid)
			end
			return true
		end)
		if not _hookState.hookMaid then
			_hookState.hookMaid = hookMaid
		end
		return hookMaid
	end
end
