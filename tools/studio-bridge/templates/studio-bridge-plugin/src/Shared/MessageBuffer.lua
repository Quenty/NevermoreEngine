--!strict
--[=[
	Fixed-capacity ring buffer of log entries. Once full, each push overwrites
	the oldest entry.

	The query-logs action pushed over the wire calls `get`, which keeps its
	lowercase name because a persistent plugin installed from an older release
	still runs action source pushed by a newer CLI.

	@class MessageBuffer
]=]

local DEFAULT_CAPACITY = 1000

local MessageBuffer = {}
MessageBuffer.ClassName = "MessageBuffer"
MessageBuffer.__index = MessageBuffer

export type LogEntry = {
	level: string,
	body: string,
	timestamp: number,
}

export type Direction = "head" | "tail"

export type BufferSnapshot = {
	entries: { LogEntry },
	total: number,
	bufferCapacity: number,
}

export type MessageBuffer = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_buffer: { LogEntry },
		_nextIndex: number,
		_count: number,
	},
	{} :: typeof({ __index = MessageBuffer })
))

--[=[
	Constructs a buffer holding at most `capacity` entries (default 1000).
]=]
function MessageBuffer.new(capacity: number?): MessageBuffer
	local self: MessageBuffer = setmetatable({} :: any, MessageBuffer)

	self._capacity = capacity or DEFAULT_CAPACITY
	self._buffer = {}
	self._nextIndex = 1
	self._count = 0

	return self
end

--[=[
	Adds an entry, overwriting the oldest one when the buffer is full.
]=]
function MessageBuffer.Push(self: MessageBuffer, entry: LogEntry)
	self._buffer[self._nextIndex] = entry
	self._nextIndex = (self._nextIndex % self._capacity) + 1
	if self._count < self._capacity then
		self._count += 1
	end
end

--[=[
	Returns up to `count` entries in chronological order. `"head"` takes the
	oldest entries, `"tail"` (the default) the newest.
]=]
function MessageBuffer.get(self: MessageBuffer, direction: Direction?, count: number?): BufferSnapshot
	local all = self:_toArray()
	local takeCount = math.min(count or #all, #all)

	local entries: { LogEntry }
	if direction == "head" then
		entries = table.move(all, 1, takeCount, 1, {})
	else
		entries = table.move(all, #all - takeCount + 1, #all, 1, {})
	end

	return {
		entries = entries,
		total = self._count,
		bufferCapacity = self._capacity,
	}
end

--[=[
	Removes every entry.
]=]
function MessageBuffer.Clear(self: MessageBuffer)
	table.clear(self._buffer)
	self._nextIndex = 1
	self._count = 0
end

--[=[
	Returns the number of entries currently stored.
]=]
function MessageBuffer.GetCount(self: MessageBuffer): number
	return self._count
end

function MessageBuffer._toArray(self: MessageBuffer): { LogEntry }
	if self._count < self._capacity then
		return table.move(self._buffer, 1, self._count, 1, {})
	end

	local result = table.move(self._buffer, self._nextIndex, self._capacity, 1, {})
	return table.move(self._buffer, 1, self._nextIndex - 1, #result + 1, result)
end

return MessageBuffer
