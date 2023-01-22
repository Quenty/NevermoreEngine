--[=[
	@class GameProductBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local PlayerBinder = require("PlayerBinder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(PlayerBinder.new("PlayerProductManager", require("PlayerProductManager"), serviceBag))
end)