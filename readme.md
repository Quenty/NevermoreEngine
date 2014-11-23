## About

This script handles players and characters loading into the game and the 
networking of information from the client to the server and vice versa. It 
handles resource management and is designed to make libraries work together.

It should be parented to `ServerScriptService.NevermoreEngine`, and is a 
`ModularScript`

Nevermore was written for use in ROBLOX.


# FAQ
## What is Nevermore?
Nevermore is Quenty's solution to reusing code on ROBLOX. It's a collaborate piece 
of work that is actively used in games. Nevermore was developed several years ago,
before Module Scripts. Now, Nevermore still provides an easy way to load modules
and ensure reusable code.

## What does Nevermore do?
Nevermore handles three things. Loading libraries, loading code, and loading characters.
To put it simply, ROBLOX's loading system when it comes to character respawn and code
loading is annoying to work with, so it's been rewritten.
 
Nevermore's libraries handle many more functions that ROBLOX does not provide. A 
majority of common methods are used in qSystems, for example, are rewritten to make
debugging easier. **These libraries are optional.**

## How do I use Nevermore?
Simple insert the files in the correct place as specified by "File sStructure" below.
Nevermore can be accessed by other scripts as being found in ReplicatedStorage, where it
moves itself. 

## Nevermore seems really hack, is it?
Yes. It is, but it's simply because ROBLOX has really weird glitches and bugs. Nevermore
is designed to streamline testing, and so it moves resources around accordingly to make sure
that it still works with debugging while resources are loaded accordingly. 

Nevermore's class system and other "hacky" elements are being redesigned right now.
Recently, the import syntax has been removed for this reason.

## How do I load up Nevermore?
Loading on the server and the client may be done by using the following code:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nevermore         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

```

However, it should be noted that Nevermore will appear in 
`ReplicatedStorage.NevermoreEngine`

Nevermore is loaded by NevermoreEngineLoader.lua, which clones it into 
ReplicatedStorage, but before doingso, runs it for the server. This guarantees 
that it knows whether or not it's in the server or client, albeit, by a hacky 
method. It also makes sure the cloned Nevermore is archivable false incase it's 
loaded in a PBS. 

```
NOTE: Setting Players.CharacterAutoLoads to false will make 
	> attempt to call nil value
show up on ROBLOX studio version "0. 135. 0. 42435"
```

Nevermore, when it loads, does two things. It creates an internal directory
that is not archivable in `ReplicatedStorage` and it clones itself into
ReplicatedStorage. Both of these are `Archivable` false. The reasons behind
doing this is complicated, but mostly it guarantees Nevermore works in solo
test mode and the server.

## Main Resources
Main resouces are scripts in Modules that end in .Main or are not disabled. 

# Nevermore Configuration
Nevermore has several configuration options that can be modified in the main 
module. 

Blacklist - The blacklist is used to ban players automatically from the game. 

## File Structure
Nevermore is designed to work with ROBLOX's services that replicate. Nevermore
should be setup like this. Nevermore Engine uses Backpack objects to store 
modules

```
<<< ROOT >>>
	Workspace
	Players
	Lighting
	ReplicatedStorage
	ServerScriptService
		Nevermore
			Modules
				...
				Game
					Client.Main
					Server.Main
			App
				NevermoreEngine
				NevermoreEngineLoader
```

`NevermoreEngineLoader` should be the only script enabled, and will queue 
loading of the rest of Nevermore.

Modules may be organized however one likes, but it is suggested that users 
follow the file structure uploaded to the git repository.

## Modules
Modules contain scripts, localscripts, and ModuleScripts. `LocalScripts` and 
`ModuleScripts` are replicated. Any script ending in .Main will execute, as well
as any script that is not disabled (Although Nevermore will complain).

Modules cache, so it is important that all required modules already exist at the
time of running.

### App
App contains specific files used by Nevermore.


Nevermore is designed to execute multiple times without breaking anything, so it
will work in a PrivateServer. Modules will be cloned, et cetera.

## Update / Change Log
This change log is *strictly* for Nevermore's module and documentation only.

##### November 21st, 2014 [0.3.0.0]
- Removed :Import() syntax
- Lots of bug fixes
- Redesign of class architecture should be coming soon
	- Specifically designed for testing
	- Existing implimentation has lots of errors
- Lots of bug fixes
- Was **not** updated to use ReplicatedFirst because of the way ROBLOX currently handles replicated first
	- Updates planned to make Nevermore more accessible
- Documentation added, more to come.

##### February 9th, 2014 [0.2.0.3]
- Fixed `RemoteEvent` Firing in server
- Updated 

##### February 8th, 2014 [0.2.0.2]
- Pushed to github
- Fixed release notes for MD

##### February 7th, 2014 [0.2.0.1]
- Made Parent argument in GetDataStreamObject optional. Defaults to bin.
- Made Parent argument in GetEventStreamObject optional. Defaults to bin.
- Added Workspace.FilteringEnabled as a property on Configuration

##### February 6th, 2014 [0.2.0.0]
- Updated system to work with Workspace.FilteringEnabled. 
- Updated so it does not warn when unregistered requests come through to prevent 
  bug with output streams looping output
  from the server on error. (ehhhh, I'm not sure how I fix that.).
- Now clients wait for DataStreamObject's to replicate from the server, instead 
  of creating them themselves, because they cannot create them themselves. 

##### February 4th, 2014 [0.1.0.9]
- Fixed character loading issue
- Moved events with character load
- Removed client loader dependency

##### February 3rd, 2014 [0.1.0.8]
- Added GetSplashEnabled function

##### February 2nd, 2014 [0.1.0.7]
- Fixed firing client bug

##### February 1st, 2014 [0.1.0.6]
- Fixed serverside bug with event storage

##### January 24th, 2014 [0.1.0.5]
- Added EventStream 
- Added new setting "EventStreamName"
- Added new bin in the replicated bin thing for EventStreams
- Add GetDataStreamObject to public API
- Add GetEventStreamObject and make it public

##### January 23th, 2014 [0.1.0.4]
- Added more documentation

##### January 20th, 2014 [0.1.0.3]
- Updated networking against. 
- Removed ypcall wrapping as ModuleScripts have been fixed.
- Fixed data replication package being cleared / nilled
- Debugged networking in server mode. 

##### January 19th, 2014 [0.1.0.2]
- Fixed problem with client / server networking

##### Janurary 4th, 2014 [0.1.0.1]
- Added SendSpawn property to DataStreams, as a networking option.
- Recursion added to modules, will now recurse through everything not a script, 
  local script, or module script in search of resources.
- ypcall wrapped Nevermore for debugging, until modulescripts are fixed.

##### Janurary 2nd, 2013 [0.1.0.0]
- Nevermore works as expected in solo mode and solotest mode
