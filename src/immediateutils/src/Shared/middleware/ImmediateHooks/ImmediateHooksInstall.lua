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
local ImmediateTypes = require("ImmediateTypes")

local DEFAULT_PRIORITY = 100

return function<C, B>(
	rt: ImmediateTypes.ImmediateRuntime<C, B>,
	scheduler: ImmediateScheduler.ImmediateScheduler?
): ImmediateCommonHooks.ImmediateRuntimeWithHooks<C, B>
	local runtime = ImmediateCommonHooks.install(rt)

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
