--[=[
	See [GameConfigBase] for API and [GameConfigService] for usage.
	@class GameConfigClient
	@client
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigBase = require("GameConfigBase")
local GameConfigBindersClient = require("GameConfigBindersClient")

local GameConfigClient = setmetatable({}, GameConfigBase)
GameConfigClient.ClassName = "GameConfigClient"
GameConfigClient.__index = GameConfigClient

function GameConfigClient.new(folder, serviceBag)
	local self = setmetatable(GameConfigBase.new(folder), GameConfigClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigBindersClient = self._serviceBag:GetService(GameConfigBindersClient)

	self:InitObservation()

	return self
end

function GameConfigClient:GetGameConfigAssetBinder()
	return self._gameConfigBindersClient.GameConfigAsset
end

return GameConfigClient