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

local GameConfig = setmetatable({}, GameConfigBase)
GameConfig.ClassName = "GameConfig"
GameConfig.__index = GameConfig

function GameConfig.new(obj: Instance, serviceBag)
	local self = setmetatable(GameConfigBase.new(obj), GameConfig)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigBindersServer = self._serviceBag:GetService(GameConfigBindersServer)

	for _, assetType in pairs(GameConfigAssetTypes) do
		GameConfigUtils.getOrCreateAssetFolder(self._obj, assetType)
	end

	self:InitObservation()

	return self
end

function GameConfig:GetGameConfigAssetBinder()
	return self._gameConfigBindersServer.GameConfigAsset
end

return GameConfig