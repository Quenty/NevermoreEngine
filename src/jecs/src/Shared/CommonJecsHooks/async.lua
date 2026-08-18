--!nonstrict
--[=[
	@class async

	Pass a function that gets access to a table called ret, the hookmaid,
	and it will execute in a new task.spawn thread. (asyncFunction only runs once.)
	This hook function itself returns the 'ret' table,
	and you can modify the 'ret' table inside the asyncFunction to store
	returned values.
]=]

local require = require(script.Parent.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Maid = require("Maid")
local getOrCreateHookState = require("ImmediateHookUtils").getOrCreateHookState

return function(rt: ImmediateTypes.ImmediateRuntime)
	return function(dis: any?, asyncFunction: (Maid.Maid, { any }) -> any)
		local hookState, hookMaid = getOrCreateHookState(rt, dis)
		if hookState._startedAsync == nil then
			hookState._startedAsync = true
			hookState._ret = {}
			hookMaid:GiveTask(task.spawn(function()
				asyncFunction(hookState._ret, hookMaid)
			end))
		end
		return hookState._ret
	end
end
