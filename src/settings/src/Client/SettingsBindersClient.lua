--[=[
	@class SettingsBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	self:Add(Binder.new("PlayerSettings", require("PlayerSettingsClient"), serviceBag))
end)