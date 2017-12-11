--- Lua-side duplication of the API of events on Roblox objects. 
-- Signals are needed for to ensure that for local events objects are passed by 
-- reference rather than by value where possible, as the BindableEvent objects 
-- always pass signal arguments by value, meaning tables will be deep copied.
-- Roblox's deep copy method parses to a non-lua table compatable format.
-- @classmod Signal

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

--- Constructs a new signal.
function Signal.new()
	local self = setmetatable({}, Signal)
	
	self.BindableEvent = Instance.new("BindableEvent")
	self.ArgData = nil
	self.ArgCount = nil
	
	return self
end

--- Fire the event with the given arguments
function Signal:Fire(...)
	self.ArgData = {...}
	self.ArgCount = select("#", ...)
	self.BindableEvent:Fire()
end
Signal.fire = Signal.Fire

--- Connect a new handler to the event, returning a connection object that
-- can be disconnected
-- @tparam function Handler Function handler
-- @treturn Connection Connection object that can be disconnected
function Signal:Connect(Handler)
	if not (typeof(Handler) == "function") then 
		error(("connect(%s)"):format(typeof(Handler)), 2)
	end

	return self.BindableEvent.Event:Connect(function()
		Handler(unpack(self.ArgData, 1, self.ArgCount))
	end)
end
Signal.connect = Signal.Connect

--- Wait for fire to be called, and return the arguments it was given.
-- @return Parameters
function Signal:Wait()
	self.BindableEvent.Event:wait()
	assert(self.ArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
	return unpack(self.ArgData, 1, self.ArgCount)
end
Signal.wait = Signal.Wait

--- Disconnects all connected events to the signal and voids the signal as unusable.
function Signal:Destroy()
	if self.BindableEvent then
		self.BindableEvent:Destroy()
		self.BindableEvent = nil
	end

	self.ArgData = nil
	self.ArgCount = nil
end

return Signal