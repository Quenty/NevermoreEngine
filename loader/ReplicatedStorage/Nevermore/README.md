## Features

* Load by name instead of instance (i.e. `require("MyModuleName")`)
* Detects cyclical requirements in module scripts
* Can also load by indexing (i.e. `require["MyModuleName"]`)
* Can be stored in `_G` or `shared` to support legacy require systems so you can do `_G.Modules["MyModuleName"]`
* Lets all modules be stored in one folder and replicates them based upon parent name
	* Server/Client/Shared code gets replicated properly
	* Does not load in submodules so libraries can be used
* Allows you to load in other modules after initialization!

## Using Nevermore's library loader

Using Nevermore is really simple. You can either keep the name Nevermore, or customize components here.

Using this loader does not require the large amount of libraries associated with it.

1) Put this script, and all of its children in ReplicatedStorage.Nevermore (or your preferred parent)

2) Put a uniquely named module in appropriate parent
	* By default `ServerScriptService.Modules` and all submodules is loaded
	* Modules in folders named "Client" or "Server" will only be available on the Client or Server
	* Modules parented to other modules will not be moved or loadable by name

3) Use the module loader
```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))
```

4) Require by name or instance. This will detect auto-cyclic issues
```lua
local MyModule = require("MyModule")
local MyOtherModule = require(script.MyOtherModule)
```

## Loading the loader

You will need to require the module. I use this code to require it. You can rename Nevermore, but all the
references to it will need to be renamed.

```lua
-- Grab the require from the ModuleScript
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))
```

I know some people have legacy loading systems that use `_G` or `_shared`. You may easily replace
these systems by storing Nevermore in `_G` or `_shared`.

```lua
_G.myModuleLoader = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

_G.myModuleLoader["MyModule"] -- Loads module
```

## Loading modules

You can then load modules from the default area as such:

### Loading by reference

You can still load by reference, like Roblox functions

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

require(script.Parent.MyModule)
```

### Loading by name

Loading by name is the main feature.

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MyModule = require("MyModule")
```

### Loading by indexing the require table

You can also load libraries by name. If they aren't there, it will error.

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MyModule = require.MyModule
```

You can also use this syntax if you want
```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MyModule = require["MyModule"]
```

By default, modules parented in ServerScriptService.Modules will be loaded.

## Cyclic detection

As long as you load all modules through Nevermore's require() function, even if
you don't use the require-by-name function, you will recieve cyclic detection of
modules being loaded.

## Automatic replication of modules

Nevermore contains a special replication model along with its require-by-name
system. Modules will are classified as the following types, and behavior changes
based upon where you require it

* Server: Any script with a folder parent named "Server" (up to the top parent)
	* Default behavior: Only requirable by name on serves
* Client: Any script with a folder parent named "Server" (up to the top parent)
	* Default behavior: Only requirable by name on client
* Shared: Any other script, these are shared on the client and server
	* Default beahvior: Only requirable by name on the script
* Submodule: Any script with a parent of a submodule (up to the top parent)
	* Default behavior: Not requirable by name at all. This helps keep the submodules
	  from having name-space collisions.

The top parent is the parent passed in with the `AddModulesFromParent`

## Adding new modules to Nevermore
You can also add new repositories to Nevermore, to require by name!

### Adding from parent
You can add modules by parent like this:
```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

require:AddModulesFromParent(ReplicatedStorage:WaitForChild("ClientModules"))
```

Note that until you add this, the loader will error if you try to load these modules! Note that
this system follows the replication behavior! So server modules will not be available on the client,
and submodules will not be loaded. Also, on the server, client/shared modules will be replicated.

### Adding individual modules

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

require:AddModulesFromParent(ReplicatedStorage:WaitForChild("ClientModules"))
```

