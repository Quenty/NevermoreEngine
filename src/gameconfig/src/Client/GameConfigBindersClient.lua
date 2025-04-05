--[=[
	@class GameConfigBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(Binder.new("GameConfig", (require :: any)("GameConfigClient"), serviceBag))
	self:Add(Binder.new("GameConfigAsset", (require :: any)("GameConfigAssetClient"), serviceBag))
end)