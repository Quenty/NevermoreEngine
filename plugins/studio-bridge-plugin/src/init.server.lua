--!strict

local RunService = game:GetService("RunService")

local currentPlugin: Plugin? = plugin

local function clonePluginTemplate(pluginScript: Instance): Instance?
	if currentPlugin and not RunService:IsRunning() then
		return pluginScript:Clone()
	end
	return nil
end

local playtestBridgeTemplate = clonePluginTemplate(script)

local modules = script:WaitForChild("modules")
local loader = (modules:FindFirstChild("LoaderUtils", true) :: Instance).Parent

local pushedModules = modules:FindFirstChild("Pushed")
if not pushedModules then
	local folder = Instance.new("Folder")
	folder.Name = "Pushed"
	folder.Parent = modules
	pushedModules = folder
end

local require = require(loader).bootstrapPlugin(modules)

local PrecompiledSources = require("PrecompiledSources")
local StudioBridgeClient = require("StudioBridgeClient")
local StudioBridgeSessionUtils = require("StudioBridgeSessionUtils")

local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" :: string) == "true"

local function getPlaytestArgs(): StudioBridgeSessionUtils.PlaytestArgs?
	if not RunService:IsRunning() then
		return nil
	end

	local ok, testArgs = pcall(function()
		return (game:GetService("StudioTestService") :: any):GetTestArgs()
	end)
	return if ok then StudioBridgeSessionUtils.getPlaytestArgs(testArgs) else nil
end

local function startPlugin(pluginObject: Plugin)
	local playtestArgs = getPlaytestArgs()
	local isPlaytestWithoutBridgePort = RunService:IsRunning() and not playtestArgs
	if not RunService:IsStudio() or isPlaytestWithoutBridgePort then
		return
	end

	if playtestArgs and RunService:IsServer() then
		local planted =
			StudioBridgeSessionUtils.findPlantedBridge(game:GetService("ServerScriptService"), playtestArgs.playtestId)
		if planted then
			planted:Destroy()
		end
	end

	local pngOk, png = pcall(function()
		return require("png")
	end)

	local stop = StudioBridgeClient.start({
		ephemeral = if IS_EPHEMERAL then { port = PORT, sessionId = SESSION_ID } else nil,
		playtestArgs = playtestArgs,
		vendorPng = if pngOk then png else nil,
		playtestBridgeTemplate = playtestBridgeTemplate,
		pushedModules = pushedModules,
	})

	pluginObject.Unloading:Connect(stop)
end

local function startPlanted()
	local playtestArgs = getPlaytestArgs()
	if not playtestArgs then
		return
	end

	local isPlantedForThisPlaytest = if RunService:IsServer()
		then StudioBridgeSessionUtils.findPlantedBridge(script.Parent :: Instance, playtestArgs.playtestId) == script
		else script:GetAttribute("PlaytestId") == playtestArgs.playtestId
	local precompiled = script:FindFirstChild("Precompiled")
	if not (isPlantedForThisPlaytest and precompiled) then
		return
	end

	local stop = StudioBridgeClient.start({
		playtestArgs = playtestArgs,
		compile = PrecompiledSources.createCompiler(precompiled),
		pushedModules = pushedModules,
	})

	script.Destroying:Connect(stop)
end

if currentPlugin then
	startPlugin(currentPlugin)
else
	startPlanted()
end
