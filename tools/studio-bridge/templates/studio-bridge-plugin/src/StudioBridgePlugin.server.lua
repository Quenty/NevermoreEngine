--!strict
--[[
	Entry point for the studio-bridge plugin. Starts StudioBridgeClient in one of
	two modes:

	- Ephemeral: the CLI substituted the build constants below, so it connects
	  straight to that port and session.
	- Persistent: the constants are left empty, so it scans for a
	  running bridge and reconnects whenever it drops.

	The plugin cannot use the Nevermore loader: rojo builds this template on its
	own from the published CLI package, without any node_modules.
]]

local RunService = game:GetService("RunService")

local StudioBridgeClient = require(script.Parent.Shared.StudioBridgeClient)
local StudioBridgeSessionUtils = require(script.Parent.Shared.StudioBridgeSessionUtils)

local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" :: string) == "true"

-- Playtests load a plugin instance into their server and client, but only when
-- Studio's "load user plugins on playtest" setting is on. Those instances cannot
-- make the HTTP requests port discovery needs, so they only connect in a
-- playtest studio-bridge started, which hands them the port and the instance id
-- of the edit session that started it.
local playtestArgs: StudioBridgeSessionUtils.PlaytestArgs? = nil
if RunService:IsRunning() then
	local ok, testArgs = pcall(function()
		return (game:GetService("StudioTestService") :: any):GetTestArgs()
	end)
	playtestArgs = if ok then StudioBridgeSessionUtils.getPlaytestArgs(testArgs) else nil
end
if not RunService:IsStudio() or (RunService:IsRunning() and not playtestArgs) then
	return
end

-- The bridge planted into this playtest's server is already its server session
if
	playtestArgs
	and RunService:IsServer()
	and StudioBridgeSessionUtils.findPlantedBridge(game:GetService("ServerScriptService"), playtestArgs.playtestId)
then
	return
end

local pngOk, png = pcall(function()
	return (require :: any)(script.Parent.Vendor.png)
end)

local stop = StudioBridgeClient.start({
	ephemeral = if IS_EPHEMERAL then { port = PORT, sessionId = SESSION_ID } else nil,
	playtestArgs = playtestArgs,
	vendorPng = if pngOk then png else nil,
})

-- Reloading the plugin destroys this script, but the socket callbacks and the
-- poll loop outlive it, leaving the old instance connected beside the new one
plugin.Unloading:Connect(stop)
