--!nonstrict
--[=[
	@class ImmediateBufferUtils

	Optional runtime extension: deferred callback and entity-delete queues on
	`rt.buffers`. Install onto a bare ImmediateRuntime; drain after every
	gameplay system so a callback error cannot leave the live queues uncleared.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecst = require("Jecst")

export type Buffers = {
	callbacks: { () -> () },
	delete: { Jecst.Entity },
}

export type ImmediateBuffersAddon = {
	buffers: Buffers,
}

export type ImmediateRuntimeWithBuffers<C = {}, B = {}> = ImmediateTypes.ImmediateRuntime<C, B> & ImmediateBuffersAddon

local ImmediateBufferUtils = {}

function ImmediateBufferUtils.install<Rt>(rt: Rt): Rt & ImmediateBuffersAddon
	local runtime = rt :: Rt & ImmediateBuffersAddon
	if runtime.buffers == nil then
		runtime.buffers = {
			callbacks = {},
			delete = {},
		}
	end
	return runtime
end

function ImmediateBufferUtils.deferCallback(rt: ImmediateRuntimeWithBuffers, callback: () -> ())
	table.insert(rt.buffers.callbacks, callback)
end

function ImmediateBufferUtils.deferDelete(rt: ImmediateRuntimeWithBuffers, entity: Jecst.Entity)
	table.insert(rt.buffers.delete, entity)
end

function ImmediateBufferUtils.flush(rt: ImmediateRuntimeWithBuffers)
	-- Snapshot-and-clear first so a callback error cannot leave the live
	-- buffers uncleared and double-fire next postSystem.
	local callbacks = rt.buffers.callbacks
	local toDelete = rt.buffers.delete
	rt.buffers.callbacks = {}
	rt.buffers.delete = {}

	for _, callback in ipairs(callbacks) do
		callback()
	end

	for _, et in ipairs(toDelete) do
		if rt.world:contains(et) then
			rt.world:delete(et)
		end
	end
end

return ImmediateBufferUtils
