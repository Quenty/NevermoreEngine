--!nonstrict
--[=[
	@class ImmediateHooksInstall

	Runtime decorator: adds hookBook + common hooks, and optionally registers
	scheduler middleware (rtbuffer flush after each system, hook GC after the tick).
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateScheduler = require("ImmediateScheduler")
local JecsImmediateCommonHooks = require("JecsImmediateCommonHooks")
local JecsImmediateHookUtils = require("JecsImmediateHookUtils")
local JecsImmediateHooksComponents = require("JecsImmediateHooksComponents")
local JecsImmediateInstall = require("JecsImmediateInstall")
local JecsImmediateUtils = require("JecsImmediateUtils")

export type ImmediateRuntime_Jecs_Hooks<Rt = {}> =
	JecsImmediateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>
	& JecsImmediateHookUtils.ImmediateJecsHookBookAddon

return function<Rt>(
	rt: JecsImmediateInstall.ImmediateRuntime_Jecs<Rt>,
	scheduler: ImmediateScheduler.ImmediateScheduler
): ImmediateRuntime_Jecs_Hooks<Rt>
	assert(rt.world, "JecsHooks requires Jecs to be installed first. Missing world")
	assert(rt.comps, "JecsHooks requires Jecs to be installed first. Missing comps")
	assert(rt.jecs, "JecsHooks requires Jecs to be installed first. Missing jecs")

	local runtime = rt :: ImmediateRuntime_Jecs_Hooks<Rt>
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
