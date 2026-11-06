--!strict
--[[
	Entry point for the bridge planted into a playtest's server, so the playtest
	has a server session without Studio loading user plugins into playtests.

	The `startPlaytest` action plants this as a Script in the edit DataModel's
	ServerScriptService, with the plugin's Shared modules and the sources
	compiled for it ahead of time under it. The playtest copies the edit
	DataModel, so it starts in the playtest's server as an ordinary Script. It
	only starts in the playtest it was planted for: anywhere else, such as a
	place saved while it was planted, it does nothing.

	Built from the plugin template, so like the plugin it cannot use the
	Nevermore loader.
]]

local RunService = game:GetService("RunService")

local PrecompiledSources = require(script.Shared.PrecompiledSources)
local StudioBridgeClient = require(script.Shared.StudioBridgeClient)
local StudioBridgeSessionUtils = require(script.Shared.StudioBridgeSessionUtils)

if not (RunService:IsRunning() and RunService:IsServer()) then
	return
end

local ok, testArgs = pcall(function()
	return (game:GetService("StudioTestService") :: any):GetTestArgs()
end)
local playtestArgs = if ok then StudioBridgeSessionUtils.getPlaytestArgs(testArgs) else nil
if not playtestArgs or StudioBridgeSessionUtils.findPlantedBridge(script.Parent, playtestArgs.playtestId) ~= script then
	return
end

local stop = StudioBridgeClient.start({
	playtestArgs = playtestArgs,
	compile = PrecompiledSources.createCompiler(script.Precompiled),
})

script.Destroying:Connect(stop)
