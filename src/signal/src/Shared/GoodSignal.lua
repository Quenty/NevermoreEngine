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

	@class Signal
]=]

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread()
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
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		_connected = true,
		_signal = signal,
		_fn = fn,
		_next = false,
	}, Connection)
end

function Connection:Disconnect()
	self._connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

Connection.Destroy = Connection.Disconnect

-- Make Connection strict
setmetatable(Connection, {
	__index = function(_, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
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

	@param handler (... T) -> () -- Function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
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
	local item = self._handlerListHead
	while item do
		if item._connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
				-- Get the freeRunnerThread to the first yield
				coroutine.resume(freeRunnerThread)
			end
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
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
	local cn;
	cn = self:Connect(function(...)
		cn:Disconnect()
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

	@param handler (... T) -> () -- One-time function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Once(fn)
	local cn;
	cn = self:Connect(function(...)
		if cn._connected then
			cn:Disconnect()
		end
		fn(...)
	end)
	return cn
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
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end
})

return Signal