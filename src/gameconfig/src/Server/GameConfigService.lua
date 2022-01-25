--[=[
	@class GameConfigService
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigPicker = require("GameConfigPicker")
local BadgeUtils = require("BadgeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Promise = require("Promise")
local GameConfigServiceConstants = require("GameConfigServiceConstants")
local GetRemoteFunction = require("GetRemoteFunction")
local Maid = require("Maid")
local GetRemoteEvent = require("GetRemoteEvent")
local GameConfig = require("GameConfig")

local GameConfigService = {}

function GameConfigService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._picker = GameConfigPicker.new()
end

function GameConfigService:Start()
	assert(self._serviceBag, "Not initialized")
	self._started = true

	-- Initialize after the game has started so we have configuration for sure
	self._remoteFunction = GetRemoteFunction(GameConfigServiceConstants.REMOTE_FUNCTION_NAME)
	self._remoteFunction.OnServerInvoke = function(...)
		return self:_handleServerInvoke(...)
	end

	self._remoteEvent = GetRemoteEvent(GameConfigServiceConstants.REMOTE_EVENT_NAME)
	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function()
		error("Cannot invoke remote event")
	end))
end

--[=[
	Adds a game config to the service.
	@param config GameConfig
]=]
function GameConfigService:AddConfig(gameConfig)
	assert(gameConfig, "No gameConfig")
	assert(self._serviceBag, "Not initialized")

	self._picker:AddConfig(gameConfig)

	if self._started then
		-- Notify all clients
		self._remoteEvent:FireAllClients(GameConfigServiceConstants.REQUEST_ADD_CONFIG, GameConfig.serialize(gameConfig))

		-- TODO: Handle config changing (or config removing)
	end
end

function GameConfigService:GetAllProductDataByNameOrId(productNameOrId)
	return self._picker:GetAllAssetDataByNameOrId(GameConfigAssetTypes.PRODUCT, productNameOrId)
end

function GameConfigService:PromiseAwardBadge(player, badgeNameOrId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(badgeNameOrId) == "string" or type(badgeNameOrId) == "number", "Bad badgeNameOrId")

	local badgeData = self._picker:FindPlaceAssetDataByNameOrId(GameConfigAssetTypes.BADGE, badgeNameOrId)
	if badgeData then
		return BadgeUtils.promiseAwardBadge(player, badgeData.assetId)
	else
		return Promise.rejected(("Unknown badgeData for %q"):format(tostring(badgeNameOrId)))
	end
end

function GameConfigService:_handleServerInvoke(_player, request)
	if request == GameConfigServiceConstants.REQUEST_CONFIGURATION_DATA then
		return self:_getConfigData()
	else
		error(("Unknown request %q"):format(tostring(request)))
	end
end

function GameConfigService:_getConfigData()
	if self._cachedConfigData then
		return self._cachedConfigData
	end

	self._cachedConfigData = GameConfigPicker.serialize(self._picker)
	return self._cachedConfigData
end

return GameConfigService