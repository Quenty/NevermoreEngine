--!strict
--[=[
	Identifies this plugin instance to the bridge: which place it is in, which
	DataModel context it runs in, and what it can do.

	@class StudioBridgeSessionUtils
]=]

local RunService = game:GetService("RunService")

local PLUGIN_VERSION = "{{PLUGIN_VERSION}}"
local MAX_SLUG_LENGTH = 24
local NONCE_VALUE_NAME = "StudioBridgeNonce"
local LAUNCH_ID_ATTRIBUTE = "StudioBridgeSessionId"

local StudioBridgeSessionUtils = {}

export type PluginContext = "edit" | "client" | "server"

export type PlaytestArgs = {
	port: number,
	instanceId: string,
	multiplayer: boolean,
}

--[=[
	Every message type the plugin can handle. Most arrive as action source pushed
	by the bridge right after registering, but the plugin advertises them up front.

	@prop CAPABILITIES { string }
	@within StudioBridgeSessionUtils
]=]
StudioBridgeSessionUtils.CAPABILITIES = table.freeze({
	"registerAction",
	"syncActions",
	"heartbeat",
	"execute",
	"queryState",
	"captureScreenshot",
	"queryDataModel",
	"queryLogs",
	"exportInstances",
	"importInstances",
	"findInstances",
	"grepScripts",
	"startPlaytest",
	"endPlaytest",
})

--[=[
	Returns the DataModel context this plugin instance runs in.
]=]
function StudioBridgeSessionUtils.getContext(): PluginContext
	if not RunService:IsRunning() then
		return "edit"
	elseif RunService:IsClient() then
		return "client"
	else
		return "server"
	end
end

function StudioBridgeSessionUtils._slugify(text: string, fallback: string): string
	local slug = string.lower(text)
	slug = string.gsub(slug, "[^%w]+", "-")
	slug = string.gsub(slug, "^%-+", "")
	slug = string.sub(slug, 1, MAX_SLUG_LENGTH)
	slug = string.gsub(slug, "%-+$", "")
	return if slug == "" then fallback else slug
end

--[=[
	Returns a short, readable id for the open place: its name as a slug plus
	`nonce`, which tells apart two Studios with the same place open.
]=]
function StudioBridgeSessionUtils.getInstanceId(placeName: string?, nonce: string): string
	local name = string.gsub(placeName or "", "%.rbxl[x]?$", "")
	return `{StudioBridgeSessionUtils._slugify(name, "place")}-{nonce}`
end

--[=[
	Returns the nonce stored under `container`, creating it on first use. The
	value is not archivable, so it lasts as long as the DataModel: plugin reloads
	keep their session id, and a fresh Studio gets a new one.
]=]
function StudioBridgeSessionUtils.getOrCreateNonce(container: Instance, createNonce: () -> string): string
	local existing = container:FindFirstChild(NONCE_VALUE_NAME)
	if existing and existing:IsA("StringValue") and existing.Value ~= "" then
		return existing.Value
	end

	local value = Instance.new("StringValue")
	value.Name = NONCE_VALUE_NAME
	value.Archivable = false
	value.Value = createNonce()
	value.Parent = container
	return value.Value
end

--[=[
	Returns the session id for an instance id and context. The clients of a
	multiplayer test share both, so they add their player's name.
]=]
function StudioBridgeSessionUtils.getSessionId(instanceId: string, context: PluginContext, playerName: string?): string
	if playerName then
		return `{instanceId}-{context}-{StudioBridgeSessionUtils._slugify(playerName, "player")}`
	end
	return `{instanceId}-{context}`
end

--[=[
	Returns the payload of the `register` message the plugin sends on connect.
]=]
function StudioBridgeSessionUtils.createRegisterPayload(
	instanceId: string,
	context: PluginContext,
	launchId: string?,
	playerName: string?
): { [string]: any }
	return {
		pluginVersion = PLUGIN_VERSION,
		instanceId = instanceId,
		context = context,
		launchId = launchId,
		playerName = playerName,
		placeName = game.Name or "Unknown",
		placeId = game.PlaceId,
		gameId = game.GameId,
		state = "Edit",
		capabilities = table.clone(StudioBridgeSessionUtils.CAPABILITIES),
	}
end

--[=[
	Returns the launch id `process run` stamped onto the place it launched
	Studio with, or nil for a place the user opened.
]=]
function StudioBridgeSessionUtils.getLaunchId(workspace: Instance): string?
	local launchId = workspace:GetAttribute(LAUNCH_ID_ATTRIBUTE)
	return if type(launchId) == "string" then launchId else nil
end

--[=[
	Returns what studio-bridge handed a playtest through its StudioTestService
	test args: the bridge port, the instance id of the edit session that
	started it, and whether it is a multiplayer test. Nil when studio-bridge
	did not start the playtest.
]=]
function StudioBridgeSessionUtils.getPlaytestArgs(testArgs: any): PlaytestArgs?
	if
		type(testArgs) == "table"
		and type(testArgs.studioBridgePort) == "number"
		and type(testArgs.studioBridgeInstanceId) == "string"
	then
		return {
			port = testArgs.studioBridgePort,
			instanceId = testArgs.studioBridgeInstanceId,
			multiplayer = type(testArgs.studioBridgePlayers) == "number",
		}
	end
	return nil
end

return StudioBridgeSessionUtils
