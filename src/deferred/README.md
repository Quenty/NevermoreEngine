## Deferred
Deferred (otherwise known as fastSpawn) implementation for Roblox

An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and unlike coroutines, does not obscure errors


## Usage
```lua
deferred(function()
	-- This is running at the next event point (or immediately, depending on event mode)
	wait(1)
	-- This is back on Roblox's task scheduler
end)
```