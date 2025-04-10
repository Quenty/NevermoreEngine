--[=[
	See [GameConfigBase] for API and [GameConfigService] for usage.
	@class GameConfig
	@server
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigBase = require("GameConfigBase")
local GameConfigBindersServer = require("GameConfigBindersServer")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigUtils = require("GameConfigUtils")
local _ServiceBag = require("ServiceBag")

local GameConfig = setmetatable({}, GameConfigBase)
GameConfig.ClassName = "GameConfig"
GameConfig.__index = GameConfig

export type GameConfig = typeof(setmetatable(
	{} :: {
		_serviceBag: any,
		_gameConfigBindersServer: any,
	},
	{} :: typeof({ __index = GameConfig })
)) & GameConfigBase.GameConfigBase

function GameConfig.new(obj: Instance, serviceBag: _ServiceBag.ServiceBag): GameConfig
	local self: GameConfig = setmetatable(GameConfigBase.new(obj) :: any, GameConfig)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigBindersServer = self._serviceBag:GetService(GameConfigBindersServer)

	for _, assetType in GameConfigAssetTypes do
		GameConfigUtils.getOrCreateAssetFolder(self._obj, assetType)
	end

	self:InitObservation()

	return self
end

function GameConfig.GetGameConfigAssetBinder(self: GameConfig)
	return self._gameConfigBindersServer.GameConfigAsset
end

return GameConfig