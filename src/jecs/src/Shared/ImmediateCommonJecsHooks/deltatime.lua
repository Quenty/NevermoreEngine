--!nonstrict
--[=[
	@class deltatime

	Returns the time gap between the last call and the current call.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(dis: any?, flagToUpdate: boolean?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		local now = os.clock()
		local lastAtClock = hookState.lastAtClock
		if lastAtClock == nil then
			hookState.lastAtClock = now
			return 0
		end

		local delta = now - lastAtClock

		if flagToUpdate == nil or flagToUpdate == true then
			hookState.lastAtClock = now
		end

		return delta
	end
end
