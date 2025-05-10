--!strict
--[=[
	See [GameConfigBase] for API and [GameConfigService] for usage.
	@class GameConfig
	@server
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigBase = require("GameConfigBase")
local GameConfigBindersServer = require("GameConfigBindersServer")
local GameConfigUtils = require("GameConfigUtils")
local ServiceBag = require("ServiceBag")

local GameConfig = setmetatable({}, GameConfigBase)
GameConfig.ClassName = "GameConfig"
GameConfig.__index = GameConfig

export type GameConfig = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_gameConfigBindersServer: any,
	},
	{} :: typeof({ __index = GameConfig })
)) & GameConfigBase.GameConfigBase

function GameConfig.new(obj: Instance, serviceBag: ServiceBag.ServiceBag): GameConfig
	local self: GameConfig = setmetatable(GameConfigBase.new(obj) :: any, GameConfig)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigBindersServer = self._serviceBag:GetService(GameConfigBindersServer)

	for _, assetType: any in GameConfigAssetTypes do
		GameConfigUtils.getOrCreateAssetFolder(self._obj, assetType)
	end

	self:InitObservation()

	return self
end

function GameConfig.GetGameConfigAssetBinder(self: GameConfig)
	return self._gameConfigBindersServer.GameConfigAsset
end

return GameConfig
