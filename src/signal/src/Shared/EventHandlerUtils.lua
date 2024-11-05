--[=[
	Utility methods to fire an event in a free thread, reusing threads

	@class EventHandlerUtils
]=]

local require = require(script.Parent.loader).load(script)

local EventHandlerUtils = {}

-- The currently idle thread to run the next handler on
local freeThreads = setmetatable({}, {__mode = "kv"})

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
function EventHandlerUtils._fireEvent(memoryCategory, fn, ...)
	local acquiredRunnerThread = freeThreads[memoryCategory]
	freeThreads[memoryCategory] = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeThreads[memoryCategory] = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
function EventHandlerUtils._initializeThread(memoryCategory)
	if #memoryCategory == 0 then
		debug.setmemorycategory("signal_unknown")
	else
		debug.setmemorycategory(memoryCategory)
	end

	-- Note: We cannot use the initial set of arguments passed to
	-- initializeThread for a call to the handler, because those
	-- arguments would stay on the stack for the duration of the thread's
	-- existence, temporarily leaking references. Without access to raw bytecode
	-- there's no way for us to clear the "..." references from the stack.
	while true do
		EventHandlerUtils._fireEvent(coroutine.yield())
	end
end

--[=[
	Safely fires an event

	@param memoryCategory string
	@param callback any
]=]
function EventHandlerUtils.fire(memoryCategory, callback, ...)
	assert(type(memoryCategory) == "string", "Bad memoryCategory")
	assert(type(callback) == "function", "Bad callback")

	if not freeThreads[memoryCategory] then
		freeThreads[memoryCategory] = coroutine.create(EventHandlerUtils._initializeThread)
		coroutine.resume(freeThreads[memoryCategory], memoryCategory)
	end

	task.spawn(freeThreads[memoryCategory], memoryCategory, callback, ...)
end

return EventHandlerUtils