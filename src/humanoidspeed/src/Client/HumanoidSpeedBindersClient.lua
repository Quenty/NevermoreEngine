--[=[
	Holds binders
	@class HumanoidSpeedBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
--[=[
	@prop HumanoidSpeed Binder<HumanoidSpeedClient>
	@within HumanoidSpeedBindersClient
]=]
	self:Add(Binder.new("HumanoidSpeed", require("HumanoidSpeedClient"), serviceBag))
end)