--!strict
--[=[
	Batched Yield-Safe Signal Implementation

	Lua-side duplication of the [API of events on Roblox objects](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal).

	Signals are needed to ensure that for local events objects are passed by
	reference rather than by value where possible, as the BindableEvent objects
	always pass signal arguments by value, meaning tables will be deep copied.
	Roblox's deep copy method parses to a non-lua table compatible format.

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
	prevents Roblox from trying to serialize and deserialize each table reference
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
	Quenty - August 21st, 2023 - Modified to fit Nevermore contract, with Moonwave docs

	@class GoodSignal
]=]

local require = require(script.Parent.loader).load(script)

local EventHandlerUtils = require("EventHandlerUtils")

--[=[
	A connection to a signal.

	@class Connection
]=]
local Connection = {}
Connection.ClassName = "Connection"

--[=[
	Whether the connection is still connected, matching [RBXScriptConnection.Connected].

	@prop Connected boolean
	@readonly
	@within Connection
]=]
Connection.__index = function(self, key)
	if key == "Connected" then
		return rawget(self, "_prev") ~= nil
	end

	return Connection[key]
end

export type SignalHandler<T...> = (T...) -> ()

-- Connections form a doubly linked list whose head is the signal itself: the newest connection's
-- _prev is the signal, so unlinking any node is O(1) without a separate reference to the signal.
-- A connection is connected exactly while it has a _prev.
export type Connection<T...> = typeof(setmetatable(
	{} :: {
		Connected: boolean,
		_memoryCategory: string,
		_prev: any,
		_fn: SignalHandler<T...>?,
	},
	{} :: typeof({ __index = Connection })
))

--[=[
	Constructs a new connection object. Not useful directly, use Signal:Connect instead.

	@param signal Signal<T...> -- The signal this connection is connected to
	@param fn (... T) -> () -- The function handler for this connection
	@param nextConnection Connection<T...>? -- The connection after this one, so the table is built at its final size
	@return Connection
]=]
function Connection.new<T...>(
	signal: Signal<T...>,
	fn: SignalHandler<T...>,
	nextConnection: Connection<T...>?
): Connection<T...>
	return setmetatable({
		-- selene: allow(incorrect_standard_library_use)
		_memoryCategory = debug.getmemorycategory(),
		_prev = signal,
		_fn = fn,
		_next = nextConnection,
	}, Connection) :: any
end

--[=[
	Returns whether the connection is still connected.

	@within Connection
	@return boolean
]=]
function Connection.IsConnected<T...>(self: Connection<T...>): boolean
	return rawget(self :: any, "_prev") ~= nil
end

--[=[
	Disconnects the connection from the signal.

	@within Connection
	@return ()
]=]
function Connection.Disconnect<T...>(self: Connection<T...>)
	local prev = rawget(self :: any, "_prev")
	if not prev then
		return
	end

	local ourNext = rawget(self :: any, "_next")
	rawset(prev, "_next", ourNext)
	if ourNext then
		rawset(ourNext, "_prev", prev)
	end

	-- Clear every field, including _next, so a disconnected connection kept around by a `Maid` or a
	-- field holds nothing alive: not its handler, not the signal, not the rest of the chain.
	table.clear(self :: any)
end

--[=[
	Alias for [Disconnect]

	@function Destroy
	@within Connection
]=]
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
		_next: Connection<T...>?,
	},
	{} :: typeof({ __index = Signal })
))

--[=[
	Constructs a new signal.
	@return Signal<T...>
]=]
function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_next = false,
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
	local head = rawget(self :: any, "_next")
	local connection = Connection.new(self, fn, head or nil)
	if head then
		rawset(head, "_prev", connection)
	end
	rawset(self :: any, "_next", connection)
	return connection
end

--[=[
	Returns the number of connected handlers to the signal.

	@return number
]=]
function Signal.GetConnectionCount<T...>(self: Signal<T...>): number
	local n = 0
	local connection: any = rawget(self :: any, "_next")
	while connection do
		n += 1
		connection = rawget(connection, "_next")
	end
	return n
end

--[=[
	Disconnects all connected events to the signal.
]=]
function Signal.DisconnectAll<T...>(self: Signal<T...>): ()
	local head = rawget(self :: any, "_next")
	while head do
		head:Disconnect()
		head = rawget(self :: any, "_next")
	end
end

--[=[
	Fire the event with the given arguments. All handlers will be invoked. Handlers follow

	:::info
	Signal:Fire(...) is implemented by running the handler functions on the
	coRunnerThread, and any time the resulting thread yielded without returning
	to us, that means that it yielded to the Roblox scheduler and has been taken
	over by Roblox scheduling, meaning we have to make a new coroutine runner.
	:::

	@param ... T -- Variable arguments to pass to handler
]=]
function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
	local connection: any = rawget(self :: any, "_next")
	while connection do
		-- capture our next node, which could after this be cleared or disconnected.
		-- any connections occuring during fire will be added at the head and not be fired
		-- in this round.
		local nextNode = rawget(connection, "_next")

		if rawget(connection, "_prev") ~= nil then -- isConnected
			EventHandlerUtils.fire(connection._memoryCategory, connection._fn, ...)

			-- A still-connected node's _next reflects any unlinking the handler did. A node the handler
			-- disconnected has been cleared, so fall back to the next node captured before the call.
			-- If the handler disconnected both itself and that next node, the walk stops early.
			nextNode = rawget(connection, "_next") or nextNode
		end

		connection = nextNode
	end
end

--[=[
	Wait for fire to be called, and return the arguments it was given.

	:::info
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
		if coroutine.status(waitingCoroutine) == "suspended" then
			task.spawn(waitingCoroutine, ...)
		end
	end)

	return coroutine.yield()
end

--[=[
	Connect a new, one-time handler to the event. Returns a connection object that can be disconnected.

	:::info
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
	Alias for [Signal.DisconnectAll]

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
