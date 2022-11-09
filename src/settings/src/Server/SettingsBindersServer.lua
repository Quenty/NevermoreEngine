--[=[
	@class SettingsBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local PlayerBinder = require("PlayerBinder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(Binder.new("PlayerSettings", require("PlayerSettings"), serviceBag))
	self:Add(PlayerBinder.new("PlayerHasSettings", require("PlayerHasSettings"), serviceBag))
end)