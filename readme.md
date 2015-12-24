## About
NevermoreEngine is a collection of useful libraries for ROBLOX development.

Pick and choose the libraries to load, and NevermoreEngine will lazily load libraries and dependencies.

## Installation
Put `NevermoreEngine.lua`'s content's in `game.ReplicatedStorage` in a ModuleScript name `NevermoreEngine`

Put all the modules in a folder in `game.ServerScriptStorage` and name them the names of their script, but without
.lua

```
game
	ReplicatedStorage
		`ModuleScript` NevermoreEngine
	ServerScriptStorage
		`Folder` Nevermore
			`Folder` qSystems
				`ModuleScript` qSystems

```

## Using NevermoreEngine

See App/readme.md

## Update / Change Log
This change log is *strictly* for Nevermore's module and documentation only.
##### December 23rd, 2015 [0.4.0.0]
- Moved NevermoreEngine into a simplified module that had 3 API components, for loading Libraries, RemoteEvents, and RemoteFunctions

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
