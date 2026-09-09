--!nonstrict
--[=[
	@class ImmediateDeferInstall

	Runtime decorator: adds `rt.defer` / `rt.defer_buffer`, and registers
	postSystem middleware to drain that queue after each gameplay system.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateScheduler = require("ImmediateScheduler")

local DEFAULT_PRIORITY = 100

export type Defer = {
	defer_buffer: { () -> () },
	defer: (callback: () -> ()) -> (),
}

export type ImmediateRuntime_Defer<Rt = {}> = Rt & ImmediateCoreUtils.ImmediateRuntime & Defer

return function<Rt>(
	rt: Rt & ImmediateCoreUtils.ImmediateRuntime,
	scheduler: ImmediateScheduler.ImmediateScheduler
): ImmediateRuntime_Defer<Rt>
	rt.defer_buffer = {}
	rt.defer = function(callback: () -> ())
		table.insert(rt.defer_buffer, callback)
	end

	scheduler:RegisterSystem({
		name = "mw_immediate_defer_flush",
		postSystem = true,
		priority = DEFAULT_PRIORITY,
		system = function()
			-- Snapshot-and-clear first so a callback error cannot leave the live
			-- buffer uncleared and double-fire next postSystem.
			assert(rt.defer_buffer, "rt.defer_buffer is not defined")
			local snapshot = table.clone(rt.defer_buffer)
			table.clear(rt.defer_buffer)
			for _, callback in ipairs(snapshot) do
				callback()
			end
		end,
	})

	return rt
end
