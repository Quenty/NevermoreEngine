--!strict
--[=[
	Queue class with better performance characteristics than table.remove()

	```lua
	local queue = Queue.new()
	queue:PushRight("a")
	queue:PushRight("b")
	queue:PushRight("c")

	while not queue:IsEmpty() do
	    local entry = queue:PopLeft()
	    print(entry) --> a, b, c
	end
	```

	@class Queue
]=]

local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

export type Queue<T> = typeof(setmetatable(
	{} :: {
		_first: number,
		_last: number,
	},
	{} :: typeof({ __index = Queue })
))

--[=[
	Constructs a new queue
	@return Queue<T>
]=]
function Queue.new<T>(): Queue<T>
	return setmetatable({
		_first = 0,
		_last = -1,
	}, Queue)
end

--[=[
	Gets the queues length

	@return number
]=]
function Queue.__len<T>(self: Queue<T>): number
	return self._last + 1 - self._first
end

--[=[
	Returns the count of the queue

	@return number
]=]
function Queue.GetCount<T>(self: Queue<T>): number
	return self._last + 1 - self._first
end

--[=[
	Pushes an entry to the left of the queue
	@param value T
]=]
function Queue.PushLeft<T>(self: Queue<T>, value: T)
	self._first = self._first - 1
	self[self._first] = value
end

--[=[
	Pushes an entry to the right of the queue
	@param value T
]=]
function Queue.PushRight<T>(self: Queue<T>, value: T)
	self._last = self._last + 1
	self[self._last] = value
end

--[=[
	Pops an entry from the left of the queue
	@return T
]=]
function Queue.PopLeft<T>(self: Queue<T>): T
	if self._first > self._last then
		error("Queue is empty")
	end

	local value = self[self._first]
	self[self._first] = nil
	self._first = self._first + 1

	return value
end

--[=[
	Pops an entry from the right of the queue
	@return T
]=]
function Queue.PopRight<T>(self: Queue<T>): T
	if self._first > self._last then
		error("Queue is empty")
	end

	local value = self[self._last]
	self[self._last] = nil
	self._last = self._last - 1

	return value
end

--[=[
	Returns true if the queue is empty
	@return boolean
]=]
function Queue.IsEmpty<T>(self: Queue<T>): boolean
	return self._first > self._last
end

return Queue