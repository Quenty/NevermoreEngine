--[=[
	Private queue class for loading system.

	@private
	@class Queue
]=]

local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

--[=[
	Constructs a new queue
	@return Queue<T>
]=]
function Queue.new()
	return setmetatable({
		_first = 0;
		_last = -1;
	}, Queue)
end

--[=[
	Pushes an entry to the left of the queue
	@param value T
]=]
function Queue:PushLeft(value)
	self._first = self._first - 1
	self[self._first] = value
end

--[=[
	Pushes an entry to the right of the queue
	@param value T
]=]
function Queue:PushRight(value)
	self._last = self._last + 1
	self[self._last] = value
end

--[=[
	Pops an entry from the left of the queue
	@return T
]=]
function Queue:PopLeft()
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
function Queue:PopRight()
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
function Queue:IsEmpty()
	return self._first > self._last
end

return Queue
