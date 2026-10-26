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

local StudioBridgeSessionUtils = {}

export type PluginContext = "edit" | "client" | "server"

export type PlaytestArgs = {
	port: number,
	instanceId: string,
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

--[=[
	Returns a short, readable id for the open place: its name as a slug plus
	`nonce`, which tells apart two Studios with the same place open.
]=]
function StudioBridgeSessionUtils.getInstanceId(placeName: string?, nonce: string): string
	local name = string.lower(placeName or "")
	name = string.gsub(name, "%.rbxl[x]?$", "")
	name = string.gsub(name, "[^%w]+", "-")
	name = string.gsub(name, "^%-+", "")
	name = string.sub(name, 1, MAX_SLUG_LENGTH)
	name = string.gsub(name, "%-+$", "")
	if name == "" then
		name = "place"
	end

	return `{name}-{nonce}`
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
	Returns the session id for an instance id and context.
]=]
function StudioBridgeSessionUtils.getSessionId(instanceId: string, context: PluginContext): string
	return `{instanceId}-{context}`
end

--[=[
	Returns the payload of the `register` message the plugin sends on connect.
]=]
function StudioBridgeSessionUtils.createRegisterPayload(instanceId: string, context: PluginContext): { [string]: any }
	return {
		pluginVersion = PLUGIN_VERSION,
		instanceId = instanceId,
		context = context,
		placeName = game.Name or "Unknown",
		placeId = game.PlaceId,
		gameId = game.GameId,
		state = "Edit",
		capabilities = table.clone(StudioBridgeSessionUtils.CAPABILITIES),
	}
end

--[=[
	Returns what studio-bridge handed a playtest through its StudioTestService
	test args: the bridge port, and the instance id of the edit session that
	started it. Nil when studio-bridge did not start the playtest.
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
		}
	end
	return nil
end

return StudioBridgeSessionUtils
