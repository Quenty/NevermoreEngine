--!nonstrict
--[=[
	@class ImmediateBufferUtils

	Deferred callback and entity-delete queues on `rt.buffers`.
	ImmediateBuffersInstall attaches these to the runtime.
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
