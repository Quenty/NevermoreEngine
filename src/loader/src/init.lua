--[=[
	Loads Nevermore and handles loading!

	This is a centralized loader that handles the following scenarios:

	* Specific layouts for npm node_modules
	* Layouts for node_modules being symlinked
	* Multiple versions of modules being used in conjunction with each other
	* Relative path requires
	* Require by name
	* Replication to client and server

	@class Loader
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local LegacyLoader = require(script.LegacyLoader)
local StaticLegacyLoader = require(script.StaticLegacyLoader)
local LoaderUtils = require(script.LoaderUtils)

local loader, metatable
if RunService:IsRunning() then
	loader = LegacyLoader.new(script)
	metatable = {
		__call = function(_self, value)
			return loader:Require(value)
		end;
		__index = function(_self, key)
			return loader:Require(key)
		end;
	}
else
	loader = StaticLegacyLoader.new()
	metatable = {
		__call = function(_self, value)
			local env = getfenv(2)
			return loader:Require(env.script, value)
		end;
		__index = function(_self, key)
			local env = getfenv(2)
			return loader:Require(env.script, key)
		end;
	}
end

--[=[
	Bootstraps the game by replicating packages to server, client, and
	shared.

	```lua
	local ServerScriptService = game:GetService("ServerScriptService")

	local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
	local packages = require(loader).bootstrapGame(ServerScriptService.ik)
	```

	:::info
	The game must be running to do this bootstrapping operation.
	:::

	@server
	@function bootstrapGame
	@param packageFolder Instance
	@return Folder -- serverFolder
	@within Loader
]=]
local function bootstrapGame(packageFolder)
	assert(typeof(packageFolder) == "Instance", "Bad instance")
	assert(RunService:IsRunning(), "Game must be running")

	loader:Lock()

	local clientFolder, serverFolder, sharedFolder = LoaderUtils.toWallyFormat(packageFolder, false)

	clientFolder.Parent = ReplicatedStorage
	sharedFolder.Parent = ReplicatedStorage
	serverFolder.Parent = ServerScriptService

	return serverFolder
end

local function bootstrapPlugin(packageFolder)
	assert(typeof(packageFolder) == "Instance", "Bad instance")
	loader = LegacyLoader.new(script)
	loader:Lock()

	local pluginFolder = LoaderUtils.toWallyFormat(packageFolder, true)
	pluginFolder.Parent = packageFolder

	return function(value)
		if type(value) == "string" then
			if pluginFolder:FindFirstChild(value) then
				return require(pluginFolder:FindFirstChild(value))
			end

			error(("Unknown module %q"):format(tostring(value)))
		else
			return require(value)
		end
	end
end

--[=[
	A type that can be loaded into a module
	@type ModuleReference ModuleScript | number | string
	@within Loader
]=]

--[=[
	Returns a function that can be used to load modules relative
	to the script specified.

	```lua
	local require = require(script.Parent.loader).load(script)

	local maid = require("Maid")
	```

	@function load
	@param script Script -- The script to load dependencies for.
	@return (moduleReference: ModuleReference) -> any
	@within Loader
]=]
local function handleLoad(moduleScript)
	assert(typeof(moduleScript) == "Instance", "Bad moduleScript")

	return loader:GetLoader(moduleScript)
end

return setmetatable({
	load = handleLoad;
	bootstrapGame = bootstrapGame;
	bootstrapPlugin = bootstrapPlugin;
}, metatable)