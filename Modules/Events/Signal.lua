-- Credit to Stravant

--[[
	class Signal
	
	Description:
		Lua-side duplication of the API of Events on Roblox objects. Needed for nicer
		syntax, and to ensure that for local events objects are passed by reference
		rather than by value where possible, as the BindableEvent objects always pass
		their signal arguments by value, meaning tables will be deep copied when that
		is almost never the desired behavior.

	local MakeSignal = Load("Signal")
	local newSignal = MakeSignal() -- Returns new Signal Object
	
		or
		
	local Signal = Load("Signal")
	local newSignal = Signal.new() -- Returns new Signal Object

	API:
		void fire(...)
			Fire the event with the given arguments.
			
		Connection connect(Function handler)
			Connect a new handler to the event, returning a connection object that
			can be disconnected.
			
		... wait()
			Wait for fire to be called, and return the arguments it was given.

		Destroy()
			Disconnects all connected events to the signal and voids the signal as unusable.
--]]

local function MakeSignal()
	
	local BindableEvent = Instance.new("BindableEvent")
	local Signal = {}
	local Connections = {}
	local BindData
	
	function Signal:fire(...)
		BindData = {...}
		BindableEvent:Fire()
	end
	Signal.Fire = Signal.fire
	
	function Signal:connect(func)
		if not func then error("connect(nil)", 2) end
		local connection = BindableEvent.Event:connect(function()
			func(unpack(BindData))
		end)
		Connections[#Connections + 1] = connection
		return connection
	end
	
	function Signal:wait()
		BindableEvent.Event:wait()
		assert(BindData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
		return unpack(BindData)
	end

	function Signal:Destroy()
		for a = 1, #Connections do
			Connections[a]:disconnect()
		end
		BindData = BindableEvent:Destroy()
		Signal = nil
	end
	
	return Signal
end

return setmetatable({new = MakeSignal}, {__call = MakeSignal})
