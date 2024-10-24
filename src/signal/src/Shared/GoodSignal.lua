--[=[
	Batched Yield-Safe Signal Implementation

	Lua-side duplication of the [API of events on Roblox objects](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal).

	Signals are needed for to ensure that for local events objects are passed by
	reference rather than by value where possible, as the BindableEvent objects
	always pass signal arguments by value, meaning tables will be deep copied.
	Roblox's deep copy method parses to a non-lua table compatable format.

	This class is designed to work both in deferred mode and in regular mode.
	It follows whatever mode is set.

	```lua
	local signal = Signal.new()

	local arg = {}

	signal:Connect(function(value)
		assert(arg == value, "Tables are preserved when firing a Signal")
	end)

	signal:Fire(arg)
	```

	:::info
	Why this over a direct [BindableEvent]? Well, in this case, the signal
	prevents Roblox from trying to serialize and desialize each table reference
	fired through the BindableEvent.
	:::

	This is a Signal class which has effectively identical behavior to a
	normal RBXScriptSignal, with the only difference being a couple extra
	stack frames at the bottom of the stack trace when an error is thrown
	This implementation caches runner coroutines, so the ability to yield in
	the signal handlers comes at minimal extra cost over a naive signal
	implementation that either always or never spawns a thread.

	Author notes:
	stravant - July 31st, 2021 - Created the file.
	Quenty - Auguest 21st, 2023 - Modified to fit Nevermore contract, with Moonwave docs

	@class GoodSignal
]=]

-- The currently idle thread to run the next handler on
local weakFreeRunnerThreadLookup = setmetatable({}, {__mode = "kv"})

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(memoryCategory, fn, ...)
	local acquiredRunnerThread = weakFreeRunnerThreadLookup[memoryCategory]
	weakFreeRunnerThreadLookup[memoryCategory] = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	weakFreeRunnerThreadLookup[memoryCategory] = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread(memoryCategory)
	if #memoryCategory == 0 then
		debug.setmemorycategory("signal_unknown")
	else
		debug.setmemorycategory(memoryCategory)
	end

	-- Note: We cannot use the initial set of arguments passed to
	-- runEventHandlerInFreeThread for a call to the handler, because those
	-- arguments would stay on the stack for the duration of the thread's
	-- existence, temporarily leaking references. Without access to raw bytecode
	-- there's no way for us to clear the "..." references from the stack.
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.ClassName = "Connection"
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		-- selene: allow(incorrect_standard_library_use)
		_memoryCategory = debug.getmemorycategory(),
		_signal = signal,
		_fn = fn,
	}, Connection)
end

function Connection:IsConnected()
	return rawget(self, "_signal") ~= nil
end

function Connection:Disconnect()
	local signal = rawget(self, "_signal")
	if not signal then
		return
	end

	-- Unhook the node. Originally the good signal would not clear this signal and
	-- rely upon GC. However, this means that connections would keep themselves and other
	-- disconnected nodes in the chain alive, keeping the function closure alive, and in return
	-- keeping the signal alive. This means a `Maid` could keep full object trees alive if a
	-- connection was made to them.

	local ourNext = rawget(self, "_next")

	if signal._handlerListHead == self then
		signal._handlerListHead = ourNext or false
	else
		local prev = signal._handlerListHead
		while prev and rawget(prev, "_next") ~= self do
			prev = rawget(prev, "_next")
		end
		if prev then
			rawset(prev, "_next", ourNext)
		end
	end

	-- Clear all member variables that aren't _next so keeping a connection
	-- indexed allows for GC of other components
	table.clear(self)
end

Connection.Destroy = Connection.Disconnect

-- Make signal strict
setmetatable(Connection, {
	__index = function(_, key)
		error(string.format("Attempt to get Connection::%s (not a valid member)", tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(string.format("Attempt to set Connection::%s (not a valid member)", tostring(key)), 2)
	end
})

-- Signal class
local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

--[=[
	Constructs a new signal.
	@return Signal<T>
]=]
function Signal.new()
	return setmetatable({
		_handlerListHead = false,
	}, Signal)
end

--[=[
	Returns whether a class is a signal

	@param value any
	@return boolean
]=]
function Signal.isSignal(value)
	return type(value) == "table"
		and getmetatable(value) == Signal
end

--[=[
	Connect a new handler to the event. Returns a connection object that can be disconnected.

	@param fn (... T) -> () -- Function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		rawset(connection, "_next", self._handlerListHead)
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

--[=[
	Disconnects all connected events to the signal.

	:::info
	Disconnect all handlers. Since we use a linked list it suffices to clear the
	reference to the head handler.
	:::
]=]
function Signal:DisconnectAll()
	self._handlerListHead = false
end

--[=[
	Fire the event with the given arguments. All handlers will be invoked. Handlers follow

	::: info
	Signal:Fire(...) is implemented by running the handler functions on the
	coRunnerThread, and any time the resulting thread yielded without returning
	to us, that means that it yielded to the Roblox scheduler and has been taken
	over by Roblox scheduling, meaning we have to make a new coroutine runner.
	:::

	@param ... T -- Variable arguments to pass to handler
]=]
function Signal:Fire(...)
	local connection = self._handlerListHead
	while connection do
		-- capture our next node, which could after this be cleared or disconnected.
		-- any connections occuring during fire will be added to the _handerListHead and not be fired
		-- in this round. Any disconnections in the chain will still work here.
		local nextNode = rawget(connection, "_next")

		if rawget(connection, "_signal") ~= nil then -- isConnected
			local memoryCategory = connection._memoryCategory

			-- Get the freeRunnerThread to the first yield
			if not weakFreeRunnerThreadLookup[memoryCategory] then
				weakFreeRunnerThreadLookup[memoryCategory] = coroutine.create(runEventHandlerInFreeThread)
				coroutine.resume(weakFreeRunnerThreadLookup[memoryCategory], memoryCategory)
			end

			task.spawn(weakFreeRunnerThreadLookup[memoryCategory], memoryCategory, connection._fn, ...)
		end

		connection = nextNode
	end
end

--[=[
	Wait for fire to be called, and return the arguments it was given.

	::: info
	Signal:Wait() is implemented in terms of a temporary connection using
	a Signal:Connect() which disconnects itself.
	:::

	@yields
	@return T
]=]
function Signal:Wait()
	local waitingCoroutine = coroutine.running()

	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)

	return coroutine.yield()
end

--[=[
	Connect a new, one-time handler to the event. Returns a connection object that can be disconnected.

	::: info
	-- Implement Signal:Once() in terms of a connection which disconnects
	-- itself before running the handler.
	:::

	@param fn (... T) -> () -- One-time function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

--[=[
	Alias for [DisconnectAll]

	@function Destroy
	@within Signal
]=]
Signal.Destroy = Signal.DisconnectAll

-- Make signal strict
setmetatable(Signal, {
	__index = function(_, key)
		error(string.format("Attempt to get Signal::%s (not a valid member)", tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(string.format("Attempt to set Signal::%s (not a valid member)", tostring(key)), 2)
	end
})

return Signal