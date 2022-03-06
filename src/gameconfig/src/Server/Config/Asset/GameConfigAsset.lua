--[=[
	@class GameConfigAsset
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetBase = require("GameConfigAssetBase")

local GameConfigAsset = setmetatable({}, GameConfigAssetBase)
GameConfigAsset.ClassName = "GameConfigAsset"
GameConfigAsset.__index = GameConfigAsset

function GameConfigAsset.new(obj, serviceBag)
	local self = setmetatable(GameConfigAssetBase.new(obj), GameConfigAsset)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return GameConfigAsset