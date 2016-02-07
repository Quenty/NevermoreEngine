# Trello
A [set-up tutorial](https://scriptinghelpers.org/blog/logging-errors-with-trello) can be found [here](https://scriptinghelpers.org/blog/logging-errors-with-trello).
Trello should be called like so:

**Server:**
```lua
local Trello			= LoadCustomLibrary("Trello"){
	trelloUsername		= "Narrev";
	boardName			= "Roblox Error Logs";
	listName			= "Errors";
	key					= "54b8fe02d0ecafa8eaca8a783d85d0bd";
	token				= "e94ad36cb37e2d2d006637714f3a216d19d1ada096073e250be45ec96930ccce";
}
```

**Client:**
```lua
local Trello = LoadCustomLibrary("Trello")
```

# ModRemote
Written by Vorlias, [documentation here](https://github.com/Vorlias/ROBLOX-ModRemote).

# Signal
**Description:**
	Lua-side duplication of the API of Events on Roblox objects. Needed for nicer
	syntax, and to ensure that for local events objects are passed by reference
	rather than by value where possible, as the BindableEvent objects always pass
	their signal arguments by value, meaning tables will be deep copied when that
	is almost never the desired behavior.
```javascript
	class Signal
	API:
		void fire(...)
		//	Fire the event with the given arguments.
			
		Connection connect(Function handler)
		//	Connect a new handler to the event, returning a connection object that
		//	can be disconnected.
			
		... wait()
		//	Wait for fire to be called, and return the arguments it was given.
	
		Destroy()
		//	Disconnects all connected events to the signal and voids the signal as unusable.
```
