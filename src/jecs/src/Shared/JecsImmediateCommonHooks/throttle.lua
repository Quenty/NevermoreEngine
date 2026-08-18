--!nonstrict
--[=[
	@class throttle

	Returns true if the last call was more than `seconds` ago.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local JecsImmediateInstall = require("JecsImmediateInstall")
local getOrCreateHookState = require("JecsImmediateHookUtils").getOrCreateHookState

return function(rt: JecsImmediateInstall.ImmediateRuntime_Jecs)
	return function(seconds: number, dis: any?, delayOnFirstCall: boolean?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis, function(_state)
			-- only allow cleanup once the throttle window has already expired,
			-- so a recreated state firing immediately matches what the old state would do
			return _state.lastRanAtClock == nil or (os.clock() - _state.lastRanAtClock) >= (_state.seconds or 0)
		end)
		hookState.seconds = seconds

		local now = os.clock()
		local lastRanAtClock = hookState.lastRanAtClock

		if lastRanAtClock == nil then
			hookState.lastRanAtClock = now
			return not delayOnFirstCall
		end

		if now - lastRanAtClock >= seconds then
			hookState.lastRanAtClock = now
			return true
		end

		return false
	end
end
