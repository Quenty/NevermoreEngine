# ModRemote
Written by Vorlias, [documentation here](https://github.com/Vorlias/ROBLOX-ModRemote).

The MIT License (MIT)

Copyright (c) 2015 Jonathan Holmes

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


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

# Maid
Manages the cleaning of events and other things.
Modified by Quenty
```javascript
API:
	HireMaid()                     // Returns a new Maid object.
 
	Maid[key] = (function)         // Adds a task to perform when cleaning up.
	Maid[key] = (event connection) // Manages an event connection. Anything that isn't a function is assumed to be this.
	Maid[key] = (Maid)             // Maids can act as an event connection, allowing a Maid to have other maids to clean up.
	Maid[key] = nil                // Removes a named task. If the task is an event, it is disconnected.
 
	Maid:GiveTask(task)            // Same as above, but uses an incremented number as a key.
	Maid:DoCleaning()              // Disconnects all managed events and performs all clean-up tasks.
```

# Deferred
Written by zserge, [documentation](https://github.com/zserge/lua-promises) can be found [here](https://github.com/zserge/lua-promises).

# TrelloErrorLogger
This module is for automatically logging errors with a Trello Board. Credit to [YonaJune](https://scriptinghelpers.org/user/8/YonaJune) for [original](https://scriptinghelpers.org/blog/logging-errors-with-trello).

To set up, first you are going to want to create a new board on [Trello](https://trello.com/).
![](http://i.imgur.com/FqaPhTm.png)

Name it whatever you like, but make sure your board is set to **public**
![](http://i.imgur.com/KbA8Klr.png)

Next, go to [this link](https://trello.com/app-key) and replace YOUR_KEY in the following link with your given Key

``https://trello.com/1/authorize?key=YOUR_KEY&name=ROBLOXErrors&expiration=never&response_type=token&scope=read,write``

![](http://i.imgur.com/xwcDx5R.png)



<h3>TrelloErrorLogger should be called like so:</h3>

**Server:**
Replace the following with [your information](https://trello.com/app-key):
![](http://i.imgur.com/9xqynfZ.png)
```lua
local TrelloErrorLogger			= LoadCustomLibrary("TrelloErrorLogger"){
	trelloUsername		= "Narrev";
	boardName			= "Roblox Error Logs";
	listName			= "Errors";
	key					= "54b8fe02d0ecafa8eaca8a783d85d0bd";
	secret				= "e94ad36cb37e2d2d006637714f3a216d19d1ada096073e250be45ec96930ccce";
}
```

**Client:**
```lua
local TrelloErrorLogger = LoadCustomLibrary("TrelloErrorLogger")
```
