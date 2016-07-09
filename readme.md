# About
Nevermore Engine is a module-loader designed to simplify the loading of libraries and unify the networking of resources between the client and server. Nevermore comes equipped with a large codebase of useful libraries intended to streamline game development on Roblox.

## Features

* **OOP** - Many of Nevermore's libraries employ Object-Oriented Programming
* **Lazy loading** - Libraries won't load unless asked to (Consequently, Nevermore will not impact game performance)
* **Many useful libraries** - Nevermore's libraries handle logical issues to decrease the number of code-based errors that occur during game development
* **Tested** - Nevermore functions properly without testing
* **Simple** - Nevermore is designed with simplicity in mind:
	* The loader itself only includes 105 lines of code
	* Fast and easy install; just paste [installer code](https://github.com/Quenty/NevermoreEngine/blob/master/Install.lua) into Command Bar
* **Open source** - Nevermore is open source. Includes modules contributed by experienced scripters!
* **Built for Roblox** - Made specifically for use on Roblox
* **Works well with existing frameworks** - Nevermore doesn't interfere with existing code

## A sample of libraries

Here are a few of the features that Nevermore's libraries offer:

* 3D rendering
* [Additive Camera effects](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/Camera)
* [Admin commands](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/NevermoreCommands)
* [Bezier Curves](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/qSystems/Bezier.lua)
* [Compass code](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/qGUI/Compass)
* [Custom Signals](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/Events#signal)
* GUI transparency and Color3 animation code
* HeldInputs
* Kinetic scrolling frame (mobile inertia scrollling)
* Material design UI code
    * Ripple
    * Snackbar
* [Player manipulation utilities](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/qSystems/qPlayer.lua) (check teammates et cetera)
* Projectile physics
* [Promises](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/Events#deferred)
* [Pseudo chat](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/OutputStream/PseudoChat)
* [RemoteEvent and RemoteFunction manager](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/Events#remotemanager)
* [Rotating text labels](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/qGUI/RotatingTextLabel.lua)
* [Screen cover effects](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/qGUI/ScreenCover.lua)
* Time formatting ([os.date](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/Utility#os))
* TimeSync between server and client
* Title generation
* Type checkers
* Useful Data Structures
* Welding
* CFrame manipulation code
* Quaternion slerp

# Get Nevermore
To Install Nevermore, paste the following code into your command bar.

```lua
local h = game:GetService("HttpService")
local e = h.HttpEnabled
h.HttpEnabled = true
loadstring(h:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/master/Install.lua"))()
h.HttpEnabled = e
```
## What you just got:

* The main NevermoreModule in `ReplicatedStorage`
* All the modules in `ServerScriptService`

Please note that installing Nevermore will **not** change any behavior in your game. Nevermore does not affect preexisting code. If you want to see the power of Nevermore try using some [Admin Commmands](https://github.com/Quenty/NevermoreEngine/tree/master/Modules/NevermoreCommands).


# Updating Nevermore

To update Nevermore, **back up your place file** and run the install code above. Existing code will be preserved, however, Nevermore's default libraries will be overridden.

----


## Usage
To load Nevermore on your server and client, use the following header code:


```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
```

### Loading a library
With the above code, you can easily load a library and all dependencies

```lua
local qSystems = LoadCustomLibrary("qSystems")
```

Libraries have different functions with a variety of useful methods. For example, let's say we want to make a lava brick.

Vanilla RobloxLua code to turn all `Part`s into killing bricks:
```lua
local function HandleTouch(Part)
	-- Recursively find the humanoid
	local Humanoid = Part:FindFirstChild("Humanoid")
	if not Humanoid then
		if Part.Parent then
			return HandleTouch(Part.Parent)
		end
	elseif Humanoid:IsA("Humanoid") then
		Part.Humanoid:TakeDamage(100)
	end
end

local function RecurseApplyLava(Parent)
	for _, Item in pairs(Parent:GetChildren()) do
		if Item:IsA("BasePart") then
			Item.Touched:connect(HandleTouch)
		end

		RecurseApplyLava(Item)
	end
end

RecurseApplyLava(workspace)
```

Simpler code utilizing Nevermore's libraries:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local qSystems = LoadCustomLibrary("qSystems")

local function HandleTouch(Part)
	local Humanoid = qSystems.GetHumanoid(Part)
	if Humanoid then
		Humanoid:TakeDamage(100)
	end
end

qSystems.CallOnChildren(workspace, function(Item)
	if Item:IsA("BasePart") then
		Item.Touched:connect(HandleTouch)
	end
end)
```


## Manual Installation
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
				... more libraries
			... more folders and libraries

```

## That's all folks!
For help or questions, contact **ONE** of the following. (You may need to follow a user to contact them on Roblox)
* Contact Narrev on Roblox
	

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
- Was **not** updated to use ReplicatedFirst because of the way Roblox currently handles replicated first
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
