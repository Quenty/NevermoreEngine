--!strict
--[=[
	@class gate
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local getOrCreateHookState = require(script.Parent).getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis)
		local hookState, _hookMaid = getOrCreateHookState(rt, dis)
		if hookState.ran then
			return false
		end
		hookState.ran = true
		return true
	end :: (any) -> boolean
end
