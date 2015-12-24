This is the main loader of NevermoreEngine. It's designed to unify loading
so that module scripts on both the client and server can safetly load resources without
seperate code (one for yielding-streamed-in-load and one instantanious)

This module is the _primary function_ of NevermoreEngine. NevermoreEngine is this script and all of the
associated libraries used to make developing on ROBLOX easier. 

## tl;dr

In short, NevermoreEngine does makes unified server-client code easy.

# What it does

* Loads libraries
* Loads remote events
* Loads remote functions
* Works on both client and server

# Where does it go?
Just stick this baby in the ReplicatedStorage in ROBLOX Studio. 

# How to safely load it?
To safely load Nevermore engine, simply `require` the script. Note that this will only work with RBX.Lua, ROBLOX's
flavor of Lua.

It's customary to put a LoadCustomLibrary API in here to make loading libraries (the main function of Nevermore) 
more available, while keeping things relatively safe.

This is the standard snippet used in Nevermore's libraries.
```lua
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local NevermoreEngine     = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary   = NevermoreEngine.LoadLibrary
```

## Caveats
* Libraries are expected in `ServerScriptStorage.Nevermore` (a folder) and won't 
* Libraries ignore all hierarchy in `ServerScriptStorage.Nevermore`
* Not intended to be used with Build mode editing 

# API
NevermoreEngine has 3 API methods that you can use. It's that simple.

`GetRemoteEvent(RemoteEventName)`

Retrieves the RemoteEvent of the RemoteEventName name, unless it already exists, in which case it returns it
* If it's on the server, will return the remote event
* IF it's on the client, will yield until the remote event is created on the server and replicated to the client


`GetRemoteFunction(RemoteFunctionName)`

Retrieves the RemoteFunction of the RemoteFunctionName, unless it already exists, in which case it returns it
* Same behavior as `GetRemoteEvent` but for remote funtions

`LoadLibrary(LibraryName)`

Retrieves the library of LibraryName using the `require(ModuleScript)` method. Will error if
such a library does not exist. It expects to find libraries in `ServerScriptStorage.Nevermore.[...]`

# Debug mode
By enabling DebugMode (set `local DEBUG_MODE = true` in script), NevermoreEngine will print out the libraries it's loading in order.

For example, you can see the requirements of `NevermoreCommandsServer` here, the Serverside component of Nevermore's commands.

```
 1 Loading:  qSystems
 1 Done loading:  qSystems
 2 Loading:  NevermoreCommandsServer
	 3 Loading:  AuthenticationServiceServer
		 4 Loading:  qString
		 4 Done loading:  qString
		 5 Loading:  QACSettings
		 5 Done loading:  QACSettings
		 6 Loading:  qPlayer
			 7 Loading:  qSystems
			 7 Done loading:  qSystems
			 8 Loading:  qCFrame
				 9 Loading:  qSystems
				 9 Done loading:  qSystems
				 10 Loading:  qInstance
					 11 Loading:  qSystems
					 11 Done loading:  qSystems
				 10 Done loading:  qInstance
			 8 Done loading:  qCFrame
		 6 Done loading:  qPlayer
	 3 Done loading:  AuthenticationServiceServer
	 12 Loading:  Character
		 13 Loading:  RawCharacter
			 14 Loading:  Type
			 14 Done loading:  Type
			 15 Loading:  qSystems
			 15 Done loading:  qSystems
		 13 Done loading:  RawCharacter
		 16 Loading:  qSystems
		 16 Done loading:  qSystems
		 17 Loading:  Type
		 17 Done loading:  Type
	 12 Done loading:  Character
	 18 Loading:  CommandSystems
		 19 Loading:  Type
		 19 Done loading:  Type
		 20 Loading:  qString
		 20 Done loading:  qString
		 21 Loading:  qSystems
		 21 Done loading:  qSystems
		 22 Loading:  QACSettings
		 22 Done loading:  QACSettings
	 18 Done loading:  CommandSystems
	 23 Loading:  PlayerId
		 24 Loading:  Type
		 24 Done loading:  Type
		 25 Loading:  qString
		 25 Done loading:  qString
		 26 Loading:  qSystems
		 26 Done loading:  qSystems
		 27 Loading:  Table
		 27 Done loading:  Table
	 23 Done loading:  PlayerId
	 28 Loading:  PlayerTagTracker
		 29 Loading:  qSystems
		 29 Done loading:  qSystems
	 28 Done loading:  PlayerTagTracker
	 30 Loading:  PseudoChatManagerServer
		 31 Loading:  PseudoChatSettings
			 32 Loading:  qColor3
				 33 Loading:  qSystems
				 33 Done loading:  qSystems
				 34 Loading:  qString
				 34 Done loading:  qString
				 35 Loading:  qMath
				 35 Done loading:  qMath
				 36 Loading:  Easing
				 36 Done loading:  Easing
			 32 Done loading:  qColor3
		 31 Done loading:  PseudoChatSettings
		 37 Loading:  PseudoChatParser
			 38 Loading:  qSystems
			 38 Done loading:  qSystems
			 39 Loading:  qString
			 39 Done loading:  qString
			 40 Loading:  PseudoChatSettings
			 40 Done loading:  PseudoChatSettings
			 41 Loading:  qMath
			 41 Done loading:  qMath
			 42 Loading:  qGUI
				 43 Loading:  qSystems
				 43 Done loading:  qSystems
				 44 Loading:  Table
				 44 Done loading:  Table
[qGUI]- IsLocal is true
			 42 Done loading:  qGUI
			 45 Loading:  OutputStream
				 46 Loading:  qSystems
				 46 Done loading:  qSystems
				 47 Loading:  Table
				 47 Done loading:  Table
				 48 Loading:  CircularBuffer
				 48 Done loading:  CircularBuffer
				 49 Loading:  Signal
				 49 Done loading:  Signal
			 45 Done loading:  OutputStream
			 50 Loading:  qTime
			 50 Done loading:  qTime
			 51 Loading:  qColor3
			 51 Done loading:  qColor3
			 52 Loading:  qPlayer
			 52 Done loading:  qPlayer
		 37 Done loading:  PseudoChatParser
		 53 Loading:  OutputClassStreamLoggers
			 54 Loading:  qSystems
			 54 Done loading:  qSystems
			 55 Loading:  CircularBuffer
			 55 Done loading:  CircularBuffer
			 56 Loading:  Table
			 56 Done loading:  Table
		 53 Done loading:  OutputClassStreamLoggers
		 57 Loading:  OutputStream
		 57 Done loading:  OutputStream
		 58 Loading:  qString
		 58 Done loading:  qString
		 59 Loading:  AuthenticationServiceServer
		 59 Done loading:  AuthenticationServiceServer
		 60 Loading:  qPlayer
		 60 Done loading:  qPlayer
	 30 Done loading:  PseudoChatManagerServer
	 61 Loading:  PseudoChatSettings
	 61 Done loading:  PseudoChatSettings
	 62 Loading:  QACSettings
	 62 Done loading:  QACSettings
	 63 Loading:  qString
	 63 Done loading:  qString
	 64 Loading:  qSystems
	 64 Done loading:  qSystems
	 65 Loading:  RawCharacter
	 65 Done loading:  RawCharacter
	 66 Loading:  Table
	 66 Done loading:  Table
	 67 Loading:  Type
	 67 Done loading:  Type
	 68 Loading:  qPlayer
	 68 Done loading:  qPlayer
 2 Done loading:  NevermoreCommandsServer
 ...
```

Each component loading is given a load ID. Failure to load something will be noted in this waterfall
version and allow for easier debugging.