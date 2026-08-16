--!nonstrict
--[=[
	@class rtbuffer

	Returns a consistent reference to a state table that, if called by a system,
	is cleared when that system ends. (still discriminated by dis, filename, line number).

	Technically not an average hook, because it persists through hot reloads
	and will never clean up. Thus, any call to this hook function will return the same
	state table whether called from any code anywhere (because it uses rt.), whether it's
	from a Maid cleanup, an Observer subscription, a system call, etc.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?)
		local hookState, hookMaid = getOrCreateHookState(rt, dis, nil, true)
		hookState.calledThisFrame = true
		if hookState.tab == nil then
			hookState.tab = {}
		end
		return hookState.tab, hookMaid
	end
end
