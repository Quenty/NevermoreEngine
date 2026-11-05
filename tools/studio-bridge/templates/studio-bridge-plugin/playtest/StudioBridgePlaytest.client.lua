--!strict
--[[
	Entry point for the bridge planted into a playtest's client, the client twin
	of StudioBridgePlaytest.server.lua: an ordinary LocalScript, so a play mode
	playtest has a client session without Studio loading user plugins into it.
	It only starts in the playtest it was planted for.
]]

local RunService = game:GetService("RunService")

local PrecompiledSources = require(script.Shared.PrecompiledSources)
local StudioBridgeClient = require(script.Shared.StudioBridgeClient)
local StudioBridgeSessionUtils = require(script.Shared.StudioBridgeSessionUtils)

if not (RunService:IsRunning() and RunService:IsClient()) then
	return
end

local ok, testArgs = pcall(function()
	return (game:GetService("StudioTestService") :: any):GetTestArgs()
end)
local playtestArgs = if ok then StudioBridgeSessionUtils.getPlaytestArgs(testArgs) else nil
if not playtestArgs or script:GetAttribute("PlaytestId") ~= playtestArgs.playtestId then
	return
end

local stop = StudioBridgeClient.start({
	playtestArgs = playtestArgs,
	compile = PrecompiledSources.createCompiler(script.Precompiled),
})

script.Destroying:Connect(stop)
