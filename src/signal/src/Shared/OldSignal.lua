--!nocheck
--[=[
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

	@class Signal
]=]

local USE_GOOD_SIGNAL_ONLY = true

if USE_GOOD_SIGNAL_ONLY then
	local require = require(script.Parent.loader).load(script)

	return require("GoodSignal")
end

local HttpService = game:GetService("HttpService")

local ENABLE_TRACEBACK = false

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

--[=[
	Returns whether a class is a signal
	@param value any
	@return boolean
]=]
function Signal.isSignal(value)
	return type(value) == "table" and getmetatable(value) == Signal
end

--[=[
	Constructs a new signal.
	@return Signal<T>
]=]
function Signal.new()
	local self = setmetatable({}, Signal)

	self._bindableEvent = Instance.new("BindableEvent")
	self._argMap = {}
	self._source = ENABLE_TRACEBACK and debug.traceback() or ""

	-- Events in Roblox execute in reverse order as they are stored in a linked list and
	-- new connections are added at the head. This event will be at the tail of the list to
	-- clean up memory.
	self._bindableEvent.Event:Connect(function(key)
		self._argMap[key] = nil

		-- We've been destroyed here and there's nothing left in flight.
		-- Let's remove the argmap too.
		-- This code may be slower than leaving this table allocated.
		if (not self._bindableEvent) and (not next(self._argMap)) then
			self._argMap = nil
		end
	end)

	return self
end

--[=[
	Fire the event with the given arguments. All handlers will be invoked. Handlers follow
	@param ... T -- Variable arguments to pass to handler
]=]
function Signal:Fire(...)
	if not self._bindableEvent then
		warn(string.format("Signal is already destroyed. %s", self._source))
		return
	end

	local args = table.pack(...)

	-- TODO: Replace with a less memory/computationally expensive key generation scheme
	local key = HttpService:GenerateGUID(false)
	self._argMap[key] = args

	-- Queues each handler onto the queue.
	self._bindableEvent:Fire(key)
end

--[=[
	Connect a new handler to the event. Returns a connection object that can be disconnected.
	@param handler (... T) -> () -- Function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Connect(handler)
	if not (type(handler) == "function") then
		error(string.format("connect(%s)", typeof(handler)), 2)
	end

	return self._bindableEvent.Event:Connect(function(key)
		-- note we could queue multiple events here, but we'll do this just as Roblox events expect
		-- to behave.

		local args = self._argMap[key]
		if args then
			handler(table.unpack(args, 1, args.n))
		else
			error("Missing arg data, probably due to reentrance.")
		end
	end)
end

--[=[
	Connect a new, one-time handler to the event. Returns a connection object that can be disconnected.
	@param handler (... T) -> () -- One-time function handler called when `:Fire(...)` is called
	@return RBXScriptConnection
]=]
function Signal:Once(handler)
	if not (type(handler) == "function") then
		error(string.format("once(%s)", typeof(handler)), 2)
	end

	return self._bindableEvent.Event:Once(function(key)
		local args = self._argMap[key]
		if args then
			handler(table.unpack(args, 1, args.n))
		else
			error("Missing arg data, probably due to reentrance.")
		end
	end)
end

--[=[
	Wait for fire to be called, and return the arguments it was given.
	@yields
	@return T
]=]
function Signal:Wait()
	local key = self._bindableEvent.Event:Wait()
	local args = self._argMap[key]
	if args then
		return table.unpack(args, 1, args.n)
	else
		error("Missing arg data, probably due to reentrance.")
		return nil
	end
end

--[=[
	Disconnects all connected events to the signal. Voids the signal as unusable.
	Sets the metatable to nil.
]=]
function Signal:Destroy()
	if self._bindableEvent then
		-- This should disconnect all events, but in-flight events should still be
		-- executed.

		self._bindableEvent:Destroy()
		self._bindableEvent = nil
	end

	-- Do not remove the argmap. It will be cleaned up by the cleanup connection.

	setmetatable(self, nil)
end

return Signal
