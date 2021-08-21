---
-- @module Queue
-- @author Quenty

local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

function Queue.new()
	return setmetatable({
		_first = 0;
		_last = -1;
	}, Queue)
end

function Queue:PushLeft(value)
	self._first = self._first - 1
	self[self._first] = value
end

function Queue:PushRight(value)
	self._last = self._last + 1
	self[self._last] = value
end

function Queue:PopLeft()
	if self._first > self._last then
		error("Queue is empty")
	end

	local value = self[self._first]
	self[self._first] = nil
	self._first = self._first + 1

	return value
end

function Queue:PopRight()
	if self._first > self._last then
		error("Queue is empty")
	end

	local value = self[self._last]
	self[self._last] = nil
	self._last = self._last - 1

	return value
end

function Queue:IsEmpty()
	return self._first > self._last
end

return Queue
