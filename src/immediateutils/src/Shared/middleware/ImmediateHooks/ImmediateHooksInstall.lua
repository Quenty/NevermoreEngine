--!nonstrict
--[=[
	@class ImmediateHooksInstall

	Runtime decorator: adds hookBook + common hooks, and optionally registers
	scheduler middleware (rtbuffer flush after each system, hook GC after the tick).
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateCommonHooks = require("ImmediateCommonHooks")
local ImmediateHookUtils = require("ImmediateHookUtils")
local ImmediateScheduler = require("ImmediateScheduler")

local DEFAULT_PRIORITY = 100

return function<Rt>(
	rt: Rt,
	scheduler: ImmediateScheduler.ImmediateScheduler?
): Rt & ImmediateCommonHooks.ImmediateHooksAddon
	local runtime = rt :: Rt & ImmediateCommonHooks.ImmediateHooksAddon
	if runtime.hookBook == nil then
		runtime.hookBook = {
			orderOfCalls = {},
			stateEntities = {},
		}
	end
	if runtime.hooks == nil then
		runtime.hooks = ImmediateCommonHooks._createHookCallbacks(runtime)
	end

	if scheduler then
		scheduler:RegisterSystem({
			name = "mw_immediate_hooks_rtbuffer",
			postSystem = true,
			priority = DEFAULT_PRIORITY,
			notProtected = false,
			system = function(r)
				ImmediateHookUtils.flushHookRuntimeBuffers(r)
			end,
			Destroy = function() end,
		})
		scheduler:RegisterSystem({
			name = "mw_immediate_hooks_gc",
			postTick = true,
			priority = DEFAULT_PRIORITY,
			notProtected = false,
			system = function(r)
				ImmediateHookUtils.evaluateAndCleanupHooks(r)
			end,
			Destroy = function() end,
		})
	end

	return runtime
end
