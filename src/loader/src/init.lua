--- Loads things
-- @module loader

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

local function bootstrapGame(packageFolder)
	assert(RunService:IsRunning(), "Game must be running")

	loader:Lock()

	local clientFolder, serverFolder, sharedFolder = LoaderUtils.toWallyFormat(packageFolder)

	clientFolder.Parent = ReplicatedStorage
	sharedFolder.Parent = ReplicatedStorage
	serverFolder.Parent = ServerScriptService

	return serverFolder
end

local function handleLoad(moduleScript)
	assert(typeof(moduleScript) == "Instance", "Bad moduleScript")

	return loader:GetLoader(moduleScript)
end

return setmetatable({
	load = handleLoad;
	bootstrapGame = bootstrapGame;
}, metatable)