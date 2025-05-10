--[=[
	@class GameConfigBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(Binder.new("GameConfig", (require :: any)("GameConfig"), serviceBag))
	self:Add(Binder.new("GameConfigAsset", (require :: any)("GameConfigAsset"), serviceBag))
end)
