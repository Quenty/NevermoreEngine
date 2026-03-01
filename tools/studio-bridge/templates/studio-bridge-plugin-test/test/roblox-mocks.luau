--[[
	Minimal Roblox service stubs for running plugin tests under Lune.

	Provides mock implementations of HttpService, RunService, LogService,
	and a simple Signal class. These are not full Roblox API replicas --
	only the subset needed by the studio-bridge plugin modules.
]]

local serde = require("@lune/serde")

-- ---------------------------------------------------------------------------
-- Signal mock
-- ---------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_callbacks = {},
	}, Signal)
end

function Signal:Connect(callback: (...any) -> ())
	local connection = {
		_signal = self,
		_callback = callback,
		Connected = true,
	}

	function connection:Disconnect()
		self.Connected = false
		for i, cb in self._signal._callbacks do
			if cb == self._callback then
				table.remove(self._signal._callbacks, i)
				break
			end
		end
	end

	table.insert(self._callbacks, callback)
	return connection
end

function Signal:Fire(...)
	-- Copy the list so disconnects during iteration are safe
	local snapshot = table.clone(self._callbacks)
	for _, callback in snapshot do
		callback(...)
	end
end

-- ---------------------------------------------------------------------------
-- HttpService mock
-- ---------------------------------------------------------------------------

local HttpService = {}

function HttpService:JSONEncode(value: any): string
	return serde.encode("json", value)
end

function HttpService:JSONDecode(json: string): any
	return serde.decode("json", json)
end

-- ---------------------------------------------------------------------------
-- RunService mock
-- ---------------------------------------------------------------------------

local RunService = {
	Heartbeat = Signal.new(),
}

function RunService:IsStudio(): boolean
	return true
end

function RunService:IsRunning(): boolean
	return false
end

function RunService:IsClient(): boolean
	return false
end

function RunService:IsServer(): boolean
	return false
end

-- ---------------------------------------------------------------------------
-- LogService mock
-- ---------------------------------------------------------------------------

local LogService = {
	MessageOut = Signal.new(),
}

-- ---------------------------------------------------------------------------
-- Module export
-- ---------------------------------------------------------------------------

return {
	Signal = Signal,
	HttpService = HttpService,
	RunService = RunService,
	LogService = LogService,
}
