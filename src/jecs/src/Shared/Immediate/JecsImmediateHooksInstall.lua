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

local DEFAULT_PRIORITY = 100

return function<Rt>(
	rt: Rt,
	scheduler: ImmediateScheduler.ImmediateScheduler?
): Rt & JecsImmediateCommonHooks.ImmediateHooksAddon
	local runtime = rt :: Rt & JecsImmediateCommonHooks.ImmediateHooksAddon
	if runtime.hookBook == nil then
		runtime.hookBook = {
			orderOfCalls = {},
			stateEntities = {},
		}
	end
	if runtime.hooks == nil then
		runtime.hooks = JecsImmediateCommonHooks._createHookCallbacks(runtime)
	end

	if scheduler then
		scheduler:RegisterSystem({
			name = "mw_immediate_hooks_rtbuffer",
			postSystem = true,
			priority = DEFAULT_PRIORITY,
			notProtected = false,
			system = function(r)
				JecsImmediateHookUtils.flushHookRuntimeBuffers(r)
			end,
			Destroy = function() end,
		})
		scheduler:RegisterSystem({
			name = "mw_immediate_hooks_gc",
			postTick = true,
			priority = DEFAULT_PRIORITY,
			notProtected = false,
			system = function(r)
				JecsImmediateHookUtils.evaluateAndCleanupHooks(r)
			end,
			Destroy = function() end,
		})
	end

	return runtime
end
