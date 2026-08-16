--!nonstrict
--[=[
	@class delayed

	Returns false for the first `seconds` seconds, then true after that.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(seconds: number, dis: any?)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)

		local now = os.clock()

		if hookState.lastRanAtClock == nil then
			hookState.lastRanAtClock = now
			return false
		end

		if now - hookState.lastRanAtClock >= seconds then
			hookState.lastRanAtClock = now
			return true
		end

		return false
	end
end
