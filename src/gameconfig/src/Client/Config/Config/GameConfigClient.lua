--!strict
--[=[
	See [GameConfigBase] for API and [GameConfigService] for usage.
	@class GameConfigClient
	@client
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigBase = require("GameConfigBase")
local GameConfigBindersClient = require("GameConfigBindersClient")
local _ServiceBag = require("ServiceBag")

local GameConfigClient = setmetatable({}, GameConfigBase)
GameConfigClient.ClassName = "GameConfigClient"
GameConfigClient.__index = GameConfigClient

export type GameConfigClient = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_gameConfigBindersClient: any,
	},
	{} :: typeof({ __index = GameConfigClient })
)) & GameConfigBase.GameConfigBase

function GameConfigClient.new(folder: Folder, serviceBag: _ServiceBag.ServiceBag): GameConfigClient
	local self = setmetatable(GameConfigBase.new(folder), GameConfigClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigBindersClient = self._serviceBag:GetService(GameConfigBindersClient)

	self:InitObservation()

	return self
end

function GameConfigClient.GetGameConfigAssetBinder(self: GameConfigClient)
	return self._gameConfigBindersClient.GameConfigAsset
end

return GameConfigClient