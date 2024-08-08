--[=[
	Provides access to settings on the client. See [SettingDefinition] which should
	register settings on the server. See [SettingsService] for server component.

	@client
	@class SettingsServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Rx = require("Rx")
local Maid = require("Maid")
local SettingsCmdrUtils = require("SettingsCmdrUtils")

local SettingsServiceClient = {}

--[=[
	Initializes the setting service. Should be done via ServiceBag.

	@param serviceBag ServiceBag
]=]
function SettingsServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("SettingRegistryServiceShared")):RegisterSettingService(self)
	self._playerSettingsBinder = self._serviceBag:GetService(require("PlayerSettingsClient"))
end

function SettingsServiceClient:Start()
	self:_setupCmdr()
end

--[=[
	Gets the local player settings
	@return PlayerSettingsClient | nil
]=]
function SettingsServiceClient:GetLocalPlayerSettings()
	return self:GetPlayerSettings(Players.LocalPlayer)
end

--[=[
	Observes the local player settings in a brio

	@return Observable<Brio<PlayerSettingsClient>>
]=]
function SettingsServiceClient:ObserveLocalPlayerSettingsBrio()
	return self:ObservePlayerSettingsBrio(Players.LocalPlayer)
end

--[=[
	Observes the local player settings

	@return Observable<PlayerSettingsClient | nil>
]=]
function SettingsServiceClient:ObserveLocalPlayerSettings()
	return self:ObservePlayerSettings(Players.LocalPlayer)
end

--[=[
	Promises the local player settings

	@param cancelToken CancellationToken
	@return Promise<PlayerSettingsClient>
]=]
function SettingsServiceClient:PromiseLocalPlayerSettings(cancelToken)
	return self:PromisePlayerSettings(Players.LocalPlayer, cancelToken)
end

--[=[
	Observes the player settings

	@param player Player
	@return Observable<PlayerSettingsClient | nil>
]=]
function SettingsServiceClient:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettings(self._playerSettingsBinder, player)
end

--[=[
	Observes the player settings in a brio

	@param player Player
	@return Observable<Brio<PlayerSettingsClient>>
]=]
function SettingsServiceClient:ObservePlayerSettingsBrio(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettingsBrio(self._playerSettingsBinder, player)
end

--[=[
	Gets a player's settings

	@param player Player
	@return PlayerSettingsClient | nil
]=]
function SettingsServiceClient:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.getPlayerSettings(self._playerSettingsBinder, player)
end

--[=[
	Promises the player's settings

	@param player Player
	@param cancelToken CancellationToken
	@return Promise<PlayerSettingsClient>
]=]
function SettingsServiceClient:PromisePlayerSettings(player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(self:ObservePlayerSettings(player):Pipe({
		Rx.where(function(x)
			return x ~= nil
		end)
	}), cancelToken)
end


function SettingsServiceClient:_setupCmdr()
	local cmdrServiceClient = self._serviceBag:GetService(require("CmdrServiceClient"))

	self._maid:GivePromise(cmdrServiceClient:PromiseCmdr()):Then(function(cmdr)
		SettingsCmdrUtils.registerSettingDefinition(cmdr, self._serviceBag)
	end)
end

function SettingsServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SettingsServiceClient