--!strict
--[=[
	Identifies this plugin instance to the bridge: which place it is in, which
	DataModel context it runs in, and what it can do.

	@class StudioBridgeSessionUtils
]=]

local RunService = game:GetService("RunService")

local PLUGIN_VERSION = "0.7.0"

local StudioBridgeSessionUtils = {}

export type PluginContext = "edit" | "client" | "server"

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
	Returns a stable id for the open place. Published places use their game and
	place ids. Unpublished places all share id 0, so they use the place name plus
	`nonce` to stay distinct from each other.
]=]
function StudioBridgeSessionUtils.getInstanceId(
	gameId: number,
	placeId: number,
	placeName: string?,
	nonce: string
): string
	if gameId ~= 0 or placeId ~= 0 then
		return `{gameId}-{placeId}`
	end

	local name = string.lower(placeName or "untitled")
	name = string.gsub(name, "%s+", "-")
	name = string.gsub(name, "[^%w%-]", "")
	if name == "" then
		name = "untitled"
	end

	return `local-{name}-{nonce}`
end

--[=[
	Returns the session id for an instance id and context.
]=]
function StudioBridgeSessionUtils.getSessionId(instanceId: string, context: PluginContext): string
	return `{instanceId}-{context}`
end

--[=[
	Returns the payload of the `register` message the plugin sends on connect.
	The plugin only runs in the edit DataModel, so its state is always `Edit`.
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

return StudioBridgeSessionUtils
