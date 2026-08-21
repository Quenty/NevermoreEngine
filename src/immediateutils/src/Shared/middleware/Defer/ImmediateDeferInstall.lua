--!nonstrict
--[=[
	@class ImmediateBuffersInstall

	Runtime decorator: adds rt.buffers, and optionally registers scheduler
	middleware to drain those queues after each gameplay system.
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
		name = "mw_immediate_buffers_flush",
		postSystem = true,
		priority = DEFAULT_PRIORITY,
		notProtected = false,
		system = function()
			-- Snapshot-and-clear first so a callback error cannot leave the live
			-- buffers uncleared and double-fire next postSystem.
			assert(rt.defer_buffer, "rt.defer_buffer is not defined")
			for _, callback in ipairs(rt.defer_buffer) do
				callback()
			end
			table.clear(rt.defer_buffer)
		end,
		Destroy = function() end,
	})

	return rt
end
