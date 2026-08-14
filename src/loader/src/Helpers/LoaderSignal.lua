--!nocheck

local freeRunnerThread = nil

local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	freeRunnerThread = acquiredRunnerThread
end

local function runEventHandlerInFreeThread()
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
	__newindex = function(_, key)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type LoaderSignal<T...> = {
	Connect: (self: LoaderSignal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: LoaderSignal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: LoaderSignal<T...>, T...) -> (),
	Wait: (self: LoaderSignal<T...>) -> T...,
}

-- LoaderSignal class
local LoaderSignal = {}
LoaderSignal.__index = LoaderSignal

function LoaderSignal.new<T...>(): LoaderSignal<T...>
	return setmetatable({
		_handlerListHead = false,
	}, LoaderSignal) :: any
end

function LoaderSignal:Connect(fn)
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function LoaderSignal:DisconnectAll()
	self._handlerListHead = false
end

function LoaderSignal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item._connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
				coroutine.resume(freeRunnerThread)
			end
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
	end
end

function LoaderSignal:Wait()
	local waitingCoroutine = coroutine.running()
	local cn
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function LoaderSignal:Once(fn)
	local cn
	cn = self:Connect(function(...)
		if cn._connected then
			cn:Disconnect()
		end
		fn(...)
	end)
	return cn
end

LoaderSignal.Destroy = LoaderSignal.DisconnectAll

setmetatable(LoaderSignal, {
	__index = function(_, key)
		error(("Attempt to get LoaderSignal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key)
		error(("Attempt to set LoaderSignal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return LoaderSignal
