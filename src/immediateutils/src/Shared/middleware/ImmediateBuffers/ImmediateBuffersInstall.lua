--!nonstrict
--[=[
	@class ImmediateBuffersInstall

	Runtime decorator: adds rt.buffers, and optionally registers scheduler
	middleware to drain those queues after each gameplay system.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateBufferUtils = require("ImmediateBufferUtils")
local ImmediateScheduler = require("ImmediateScheduler")

local DEFAULT_PRIORITY = 100

return function<Rt>(
	rt: Rt,
	scheduler: ImmediateScheduler.ImmediateScheduler?
): Rt & ImmediateBufferUtils.ImmediateBuffersAddon
	local runtime = rt :: Rt & ImmediateBufferUtils.ImmediateBuffersAddon
	if runtime.buffers == nil then
		runtime.buffers = {
			callbacks = {},
			delete = {},
		}
	end

	if scheduler then
		scheduler:RegisterSystem({
			name = "mw_immediate_buffers_flush",
			postSystem = true,
			priority = DEFAULT_PRIORITY,
			notProtected = false,
			system = function(r)
				ImmediateBufferUtils.flush(r)
			end,
			Destroy = function() end,
		})
	end

	return runtime
end
