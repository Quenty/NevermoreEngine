--- Nevermore module loader.
-- Used to simply module loading
-- @module Nevermore

--[[
USAGE:

See README.md
https://github.com/Quenty/NevermoreEngine/blob/version2/loader/ReplicatedStorage/Nevermore/README.md

In general usage is simple
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
]]

local REPLICATION_FOLDER_NAME = "_replicationFolder"

--- Set this value to nil if you don't want to load modules by default
local SERVER_SCRIPT_SERVICE_MODULES = "NevermoreEngine"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ModuleScriptLoader = require(script:WaitForChild("ModuleScriptLoader"))
local ReplicationUtils = require(script:WaitForChild("ReplicationUtils"))

if RunService:IsServer() and RunService:IsClient() or (not RunService:IsRunning()) then
	if RunService:IsRunning() then
		warn("Warning: Loading all modules in PlaySolo. It's recommended you use accurate play solo.")
	end

	local loader = ModuleScriptLoader.new({
		-- Allowed modules
		ReplicationUtils.ScriptType.SHARED;
		ReplicationUtils.ScriptType.SERVER;
		ReplicationUtils.ScriptType.CLIENT;
	})

	if SERVER_SCRIPT_SERVICE_MODULES then
		loader:AddModulesFromParent(ServerScriptService:WaitForChild(SERVER_SCRIPT_SERVICE_MODULES))
	end

	return loader
elseif RunService:IsServer() then
	local replicationFolder = ReplicationUtils.createReplicationFolder(REPLICATION_FOLDER_NAME)

	local loader = ModuleScriptLoader.new(
		{
			-- Allowed modules
			ReplicationUtils.ScriptType.SHARED;
			ReplicationUtils.ScriptType.SERVER;
		},
		{
			-- Replication map
			[ReplicationUtils.ScriptType.CLIENT] = replicationFolder;
			[ReplicationUtils.ScriptType.SHARED] = replicationFolder;
		})

	if SERVER_SCRIPT_SERVICE_MODULES then
		loader:AddModulesFromParent(ServerScriptService:WaitForChild(SERVER_SCRIPT_SERVICE_MODULES))
	end

	return loader
elseif RunService:IsClient() then
	local loader = ModuleScriptLoader.new({
		-- Allowed modules
		ReplicationUtils.ScriptType.SHARED;
		ReplicationUtils.ScriptType.CLIENT;
	})

	loader:AddModulesFromParent(ReplicatedStorage:WaitForChild(REPLICATION_FOLDER_NAME))

	return loader
else
	error("Error: Unknown state")
end
