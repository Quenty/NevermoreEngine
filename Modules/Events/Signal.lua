--[[
class Signal
	
Description:
	Lua-side duplication of the API of Events on Roblox objects. Needed for nicer
	syntax, and to ensure that for local events objects are passed by reference
	rather than by value where possible, as the BindableEvent objects always pass
	their signal arguments by value, meaning tables will be deep copied when that
	is almost never the desired behavior.
		
API:
	void Fire(...)
		Fire the event with the given arguments.
		
	Connection Connect(Function handler)
		Connect a new handler to the event, returning a connection object that
		can be disconnected.
		
	... Wait()
		Wait for fire to be called, and return the arguments it was given.

	Destroy()
		Disconnects all connected events to the signal and voids the signal as unusable.
]]

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

function Signal.new()
	local self = setmetatable({}, Signal)
	
	self.BindableEvent = Instance.new("BindableEvent")
	self.ArgData = nil
	self.ArgCount = nil
	
	return self
end

function Signal:Fire(...)
	self.ArgData = {...}
	self.ArgCount = select("#", ...)
	self.BindableEvent:Fire()
end
Signal.fire = Signal.Fire

function Signal:Connect(Handler)
	if not Handler then 
		error("connect(nil)", 2) 
	end

	return self.BindableEvent.Event:Connect(function()
		Handler(unpack(self.ArgData, 1, self.ArgCount))
	end)
end
Signal.connect = Signal.Connect

function Signal:Wait()
	self.BindableEvent.Event:wait()
	assert(self.ArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
	return unpack(self.ArgData, 1, self.ArgCount)
end
Signal.wait = Signal.Wait

function Signal:Destroy()
	if self.BindableEvent then
		self.BindableEvent:Destroy()
		self.BindableEvent = nil
	end

	self.ArgData = nil
	self.ArgCount = nil
end

return Signal