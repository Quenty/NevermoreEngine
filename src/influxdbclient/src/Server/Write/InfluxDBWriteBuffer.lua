--!strict
--[=[
	@class InfluxDBWriteBuffer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local Signal = require("Signal")
local _InfluxDBWriteOptionUtils = require("InfluxDBWriteOptionUtils")

local InfluxDBWriteBuffer = setmetatable({}, BaseObject)
InfluxDBWriteBuffer.ClassName = "InfluxDBWriteBuffer"
InfluxDBWriteBuffer.__index = InfluxDBWriteBuffer

export type InfluxDBWriteBuffer = typeof(setmetatable(
	{} :: {
		_bytes: number,
		_length: number,
		_entries: { string },
		_writeOptions: _InfluxDBWriteOptionUtils.InfluxDBWriteOptions,
		_promiseHandleFlush: (entries: { string }) -> Promise.Promise<()>,
		_requestQueueNext: Signal.Signal<()>,
	},
	{} :: typeof({ __index = InfluxDBWriteBuffer })
)) & BaseObject.BaseObject

function InfluxDBWriteBuffer.new(
	writeOptions: _InfluxDBWriteOptionUtils.InfluxDBWriteOptions,
	promiseHandleFlush
): InfluxDBWriteBuffer
	local self: InfluxDBWriteBuffer = setmetatable(BaseObject.new() :: any, InfluxDBWriteBuffer)

	self._writeOptions = assert(writeOptions, "Bad writeOptions")
	self._promiseHandleFlush = assert(promiseHandleFlush, "No promiseHandleFlush")

	self._entries = {}
	self._bytes = 0
	self._length = 0

	self._requestQueueNext = self._maid:Add(Signal.new())

	return self
end

function InfluxDBWriteBuffer.Add(self: InfluxDBWriteBuffer, entry: string)
	assert(type(entry) == "string", "Bad entry")

	-- Already overflowing
	if self._bytes + #entry + 1 >= self._writeOptions.maxBatchBytes then
		self:_promiseFlushAll()
	end

	table.insert(self._entries, entry)

	self._bytes = self._bytes + #entry + 1
	self._length = self._length + 1

	if self._length >= self._writeOptions.batchSize or self._bytes >= self._writeOptions.maxBatchBytes then
		self:_promiseFlushAll()
	else
		self:_queueNextSend()
	end
end

function InfluxDBWriteBuffer._queueNextSend(self: InfluxDBWriteBuffer)
	if self._maid._queuedSendTask then
		return
	end

	self._maid._queuedSendTask = task.delay(self._writeOptions.flushIntervalSeconds, function()
		task.defer(function()
			if self.Destroy then
				self:_promiseFlushAll()
			end
		end)
	end)
end

function InfluxDBWriteBuffer._reset(self: InfluxDBWriteBuffer)
	local entries = self._entries

	self._bytes = 0
	self._length = 0
	self._entries = {}

	return entries
end

function InfluxDBWriteBuffer._promiseFlushAll(self: InfluxDBWriteBuffer)
	self._maid._queuedSendTask = nil

	local entries = self:_reset()
	if #entries > 0 then
		return self._promiseHandleFlush(entries)
	else
		return Promise.resolved()
	end
end

function InfluxDBWriteBuffer.PromiseFlush(self: InfluxDBWriteBuffer)
	return self:_promiseFlushAll()
end

return InfluxDBWriteBuffer