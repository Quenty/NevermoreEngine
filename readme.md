---------
META DATA
---------
@author Quenty
Version 0.2.0.2

This script handles players and characters loading into the game and the 
networking of information from the client to the server and vice versa. It 
handles resource management and is designed to make libraries work together.

It should be parented to ServerScriptService, and is a ModularScript

--------------
File Structure
--------------
Nevermore is designed to work with ROBLOX's services that replicate. Nevermore
should be setup like this

<<< ROOT >>>
	Workspace
	Players
	Lighting
	ReplicatedStorage
	ServerScriptService
		Nevermore
			Modules
				...
				Client.Main
				Server.Main
			App
				NevermoreEngine
				NevermoreEngineLoader

Modules
-------
Modules contain scripts, localscripts, and ModuleScripts. LocalScripts and 
ModuleScripts are replciated. Any script ending in .Main will execute, as well
as any script that is not disabled (Although Nevermore will complain).

Modules cache, so it is important that all required modules already exist at the
time of running.

App
---
App contains specific files used by Nevermore.


Nevermore is designed to execute multiple times without breaking anything, so it
will work in a PrivateServer. Modules will be cloned, et cetera.

Loading
-------
Loading on the server and the client may be done by using the following code:

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nevermore         = require(ReplicatedStorage:WaitForChild("NevermoreEngine")))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0))

-----

However, it should be noted that Nevermore will appear in ReplicatedStorage.NevermoreEngine

Nevermore is loaded by NevermoreEngineLoader.lua, which clones it into ReplicatedStorage, but before doing
so, runs it for the server. This guarantees that it knows whether or not it's in the server or client, albeit,
by a hacky method. It also makes sure the cloned Nevermore is archivable false incase it's loaded in a PBS. 

NOTE: Setting Players.CharacterAutoLoads to false will make 
	> attempt to call nil value
show up on ROBLOX studio version "0. 135. 0. 42435"

MAIN RESOURCES
--------------
Main resouces are scripts in Modules that end in .Main or are not disabled. 

-------------------
Update / Change Log
-------------------
February 8th, 2014 [0.2.0.2]
- Pushed to github
- Fixed release notes for MD

February 7th, 2014 [0.2.0.1]
- Made Parent argument in GetDataStreamObject optional. Defaults to bin.
- Made Parent argument in GetEventStreamObject optional. Defaults to bin.
- Added Workspace.FilteringEnabled as a property on Configuration

February 6th, 2014 [0.2.0.0]
- Updated system to work with Workspace.FilteringEnabled. 
- Updated so it does not warn when unregistered requests come through to prevent bug with output streams looping output
  from the server on error. (ehhhh, I'm not sure how I fix that.).
- Now clients wait for DataStreamObject's to replicate from the server, instead of creating them themselves, because they
  cannot create them themselves. 

February 4th, 2014 [0.1.0.9]
- Fixed character loading issue
- Moved events with character load
- Removed client loader dependency

February 3rd, 2014 [0.1.0.8]
- Added GetSplashEnabled function

February 2nd, 2014 [0.1.0.7]
- Fixed firing client bug

February 1st, 2014 [0.1.0.6]
- Fixed serverside bug with event storage

January 24th, 2014 [0.1.0.5]
- Added EventStream 
- Added new setting "EventStreamName"
- Added new bin in the replicated bin thing for EventStreams
- Add GetDataStreamObject to public API
- Add GetEventStreamObject and make it public

January 23th, 2014 [0.1.0.4]
- Added more documentation

January 20th, 2014 [0.1.0.3]
- Updated networking against. 
- Removed ypcall wrapping as ModuleScripts have been fixed.
- Fixed data replication package being cleared / nilled
- Debugged networking in server mode. 

January 19th, 2014 [0.1.0.2]
- Fixed problem with client / server networking

Janurary 4th, 2014 [0.1.0.1]
- Added SendSpawn property to DataStreams, as a networking option.
- Recursion added to modules, will now recurse through everything not a script, local script, or module script in search
  of resources.
- ypcall wrapped Nevermore for debugging, until modulescripts are fixed.

Janurary 2nd, 2013 [0.1.0.0]
- Nevermore works as expected in solo mode and solotest mode


