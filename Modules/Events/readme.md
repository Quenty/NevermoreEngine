# Trello
A set-up tutorial can be found [here](https://scriptinghelpers.org/blog/logging-errors-with-trello).
Trello should be called like so:
Server:
```lua
local Trello			= LoadCustomLibrary("Trello"){
	trelloUsername			= "Narrev";
	boardName			= "Roblox Error Logs";
	listName			= "Errors";
	key					= "54b8fe02d0ecafa8eaca8a783d85d0bd";
	token				= "e94ad36cb37e2d2d006637714f3a216d19d1ada096073e250be45ec96930ccce";
}
```

Client:
```lua
local Trello = LoadCustomLibrary("Trello")
```
