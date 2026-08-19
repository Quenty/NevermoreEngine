--!nonstrict
local require = require(script.Parent.loader).load(script)

local JecsImemdiateHookUtils = require("JecsImmediateHookUtils")
local ImmediateScheduler = require("ImmediateScheduler")
local Maid = require("Maid")

local function _hooks<Rt>(rt: JecsImemdiateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>)
    return {
        async = function(dis: any?, asyncFunction: (Maid.Maid, { any }) -> any)
            type AsyncHookState = {
                _startedAsync: boolean?,
                _ret: any?,
            }
            local hookState, hookMaid = JecsImemdiateHookUtils.getOrCreateHookState<AsyncHookState>(rt, dis)

            if hookState._startedAsync == nil then
                hookState._startedAsync = true
                hookState._ret = {}
                hookMaid:GiveTask(task.spawn(function()
                    asyncFunction(hookState._ret, hookMaid)
                end))
            end
            return hookState._ret
        end
    }
end

return function<Rt>(
	rt: JecsImemdiateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>,
	scheduler: ImmediateScheduler.ImmediateScheduler
): JecsImemdiateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>
	assert(rt.world, "JecsHooks requires Jecs to be installed first. Missing world")
	assert(rt.comps, "JecsHooks requires Jecs to be installed first. Missing comps")
	assert(rt.jecs, "JecsHooks requires Jecs to be installed first. Missing jecs")
	local runtime = rt :: JecsImemdiateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>

    

	if runtime.comps.MetaHookState == nil then
		JecsImmediateUtils._registerComponentsWithWorld(
			runtime.world,
			runtime.comps,
			JecsImmediateHooksComponents(runtime.world)
		)
	end
	if runtime._hookBook == nil then
		runtime._hookBook = {
			orderOfCalls = {},
			stateEntities = {},
		}
	end
	if runtime.hooks == nil then
		runtime.hooks = JecsImmediateCommonHooks(runtime)
	end

	scheduler:RegisterSystem({
		name = "mw_immediate_hooks_rtbuffer",
		postSystem = true,
		notProtected = false,
		system = function(r)
			JecsImmediateHookUtils.flushHookRuntimeBuffers(r)
		end,
		Destroy = function() end,
	})
	scheduler:RegisterSystem({
		name = "mw_immediate_hooks_gc",
		postTick = true,
		notProtected = false,
		system = function(r)
			JecsImmediateHookUtils.evaluateAndCleanupHooks(r)
		end,
		Destroy = function() end,
	})

	return runtime
end
