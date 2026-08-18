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
local JecsImmediateInstall = require("JecsImmediateInstall")

return function<Rt>(
	rt: JecsImmediateInstall.ImmediateRuntime_Jecs<Rt>,
	scheduler: ImmediateScheduler.ImmediateScheduler -- ): JecsImmediateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>
): Rt & JecsImmediateInstall.ImmediateRuntime_Jecs<Rt> & JecsImmediateHookUtils.ImmediateHookBookAddon
	assert(rt.world, "JecsHooks requires Jecs to be installed first. Missing world")
	assert(rt.comps, "JecsHooks requires Jecs to be installed first. Missing comps")
	assert(rt.jecs, "JecsHooks requires Jecs to be installed first. Missing jecs")

	-- local runtime = rt :: JecsImmediateHookUtils.ImmediateRuntime_Jecs_Hooks<Rt>
	local runtime = rt
	if runtime.hookBook == nil then
		runtime.hookBook = {
			orderOfCalls = {},
			stateEntities = {},
		}
	end
	if runtime.hooks == nil then
		runtime.hooks = JecsImmediateCommonHooks._createHookCallbacks(runtime)
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
