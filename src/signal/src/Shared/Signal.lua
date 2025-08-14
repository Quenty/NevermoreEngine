--!strict
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

local require = require(script.Parent.loader).load(script)

local EventHandlerUtils = require("EventHandlerUtils")

-- Connection class
local Connection = {}
Connection.ClassName = "Connection"
Connection.__index = Connection

export type SignalHandler<T...> = (T...) -> ()

export type Connection<T...> = typeof(setmetatable(
	{} :: {
		_memoryCategory: string,
		_signal: Signal<T...>?,
		_fn: SignalHandler<T...>?,
	},
	{} :: typeof({ __index = Connection })
))

function Connection.new<T...>(signal: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	return setmetatable({
		-- selene: allow(incorrect_standard_library_use)
		_memoryCategory = debug.getmemorycategory(),
		_signal = signal,
		_fn = fn,
	}, Connection) :: any
end

function Connection.IsConnected<T...>(self: Connection<T...>): boolean
	return rawget(self :: any, "_signal") ~= nil
end

function Connection.Disconnect<T...>(self: Connection<T...>)
	local signal = rawget(self :: any, "_signal")
	if not signal then
		return
	end

	-- Unhook the node. Originally the good signal would not clear this signal and
	-- rely upon GC. However, this means that connections would keep themselves and other
	-- disconnected nodes in the chain alive, keeping the function closure alive, and in return
	-- keeping the signal alive. This means a `Maid` could keep full object trees alive if a
	-- connection was made to them.

	local ourNext = rawget(self :: any, "_next")

	if signal._handlerListHead == self then
		signal._handlerListHead = ourNext or false
	else
		local prev = signal._handlerListHead
		while prev and rawget(prev, "_next") ~= self do
			prev = rawget(prev, "_next")
		end
		if prev then
			assert(rawget(prev, "_next") == self, "Bad state")
			rawset(prev, "_next", ourNext)
		end
	end

	-- Clear all member variables that aren't _next so keeping a connection
	-- indexed allows for GC of other components
	table.clear(self :: any)
end

Connection.Destroy = Connection.Disconnect

-- Make signal strict
setmetatable(Connection, {
	__index = function(_, key)
		error(string.format("Attempt to get Connection::%s (not a valid member)", tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(string.format("Attempt to set Connection::%s (not a valid member)", tostring(key)), 2)
	end,
})

-- Signal class
local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlerListHead: Connection<T...> | false,
	},
	{} :: typeof({ __index = Signal })
))

--[=[
	Constructs a new signal.
	@return Signal<T...>
]=]
function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_handlerListHead = false,
	}, Signal) :: any
end

--[=[
	Returns whether a class is a signal

	@param value any
	@return boolean
]=]
function Signal.isSignal(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

--[=[
	Connect a new handler to the event. Returns a connection object that can be disconnected.

	@param fn (... T) -> () -- Function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal.Connect<T...>(self: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		rawset(connection :: any, "_next", self._handlerListHead)
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function Signal:GetConnectionCount()
	local n = 0
	local prev = self._handlerListHead
	while prev do
		n += 1
		prev = rawget(prev, "_next")
	end
	return n
end

--[=[
	Disconnects all connected events to the signal.

	:::info
	Disconnect all handlers. Since we use a linked list it suffices to clear the
	reference to the head handler.
	:::
]=]
function Signal.DisconnectAll<T...>(self: Signal<T...>): ()
	while self._handlerListHead do
		local last = self._handlerListHead
		last:Disconnect()
		assert(self._handlerListHead ~= last, "self._handlerListHead should not be last")
	end

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
function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
	local connection: any = self._handlerListHead
	while connection do
		-- capture our next node, which could after this be cleared or disconnected.
		-- any connections occuring during fire will be added to the _handerListHead and not be fired
		-- in this round. Any disconnections in the chain will still work here.
		local nextNode = rawget(connection, "_next")

		if rawget(connection, "_signal") ~= nil then -- isConnected
			EventHandlerUtils.fire(connection._memoryCategory, connection._fn, ...)
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
function Signal.Wait<T...>(self: Signal<T...>): T...
	local waitingCoroutine = coroutine.running()

	local connection: Connection<T...>
	connection = (self :: any):Connect(function(...)
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
function Signal.Once<T...>(self: Signal<T...>, fn: SignalHandler<T...>): Connection<T...>
	local connection: Connection<T...>
	connection = (self :: any):Connect(function(...)
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
	end,
})

return Signal
