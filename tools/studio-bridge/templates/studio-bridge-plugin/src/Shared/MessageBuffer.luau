--[[
	Fixed-capacity ring buffer for storing log entries.

	Entries are added via push(). When the buffer reaches capacity, new entries
	overwrite the oldest. Retrieval via get() supports both "head" (oldest first)
	and "tail" (newest first) directions with an optional count limit.

	No Roblox APIs. Pure logic, testable under Lune.
]]

local MessageBuffer = {}
MessageBuffer.__index = MessageBuffer

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

--[[
	Create a new MessageBuffer with the given capacity.

	@param capacity Maximum number of entries (default 1000).
]]
function MessageBuffer.new(capacity: number?)
	local cap = capacity or 1000
	local self = setmetatable({
		_capacity = cap,
		_buffer = {} :: { { level: string, body: string, timestamp: number } },
		_head = 1, -- next write position (1-indexed)
		_count = 0, -- number of entries currently stored
	}, MessageBuffer)
	return self
end

-- ---------------------------------------------------------------------------
-- Push an entry into the buffer
-- ---------------------------------------------------------------------------

--[[
	Add an entry to the buffer. Overwrites the oldest entry if at capacity.

	@param entry Table with level, body, timestamp fields.
]]
function MessageBuffer.push(self: any, entry: {
	level: string,
	body: string,
	timestamp: number,
})
	self._buffer[self._head] = entry
	self._head = (self._head % self._capacity) + 1
	if self._count < self._capacity then
		self._count = self._count + 1
	end
end

-- ---------------------------------------------------------------------------
-- Get entries from the buffer
-- ---------------------------------------------------------------------------

--[[
	Retrieve entries from the buffer.

	@param direction "head" for oldest first, "tail" for newest first (default "tail").
	@param count Maximum number of entries to return (default: all).
	@return Table with entries, total, and bufferCapacity.
]]
function MessageBuffer.get(self: any, direction: string?, count: number?): {
	entries: { { level: string, body: string, timestamp: number } },
	total: number,
	bufferCapacity: number,
}
	local dir = direction or "tail"
	local all = self:_toArray()
	local maxCount = count or #all
	local entries = {}

	if dir == "head" then
		-- Oldest first, take from the start
		for i = 1, math.min(maxCount, #all) do
			table.insert(entries, all[i])
		end
	else
		-- Newest first (tail), take from the end
		local start = math.max(1, #all - maxCount + 1)
		for i = start, #all do
			table.insert(entries, all[i])
		end
	end

	return {
		entries = entries,
		total = self._count,
		bufferCapacity = self._capacity,
	}
end

-- ---------------------------------------------------------------------------
-- Clear the buffer
-- ---------------------------------------------------------------------------

function MessageBuffer.clear(self: any)
	self._buffer = {}
	self._head = 1
	self._count = 0
end

-- ---------------------------------------------------------------------------
-- Get the number of entries
-- ---------------------------------------------------------------------------

function MessageBuffer.size(self: any): number
	return self._count
end

-- ---------------------------------------------------------------------------
-- Internal: convert ring buffer to a chronological array
-- ---------------------------------------------------------------------------

function MessageBuffer._toArray(self: any): { { level: string, body: string, timestamp: number } }
	local result = {}
	if self._count < self._capacity then
		-- Buffer not full: entries are at indices 1..count
		for i = 1, self._count do
			table.insert(result, self._buffer[i])
		end
	else
		-- Buffer full: oldest entry is at _head, wrap around
		for i = self._head, self._capacity do
			table.insert(result, self._buffer[i])
		end
		for i = 1, self._head - 1 do
			table.insert(result, self._buffer[i])
		end
	end
	return result
end

return MessageBuffer
