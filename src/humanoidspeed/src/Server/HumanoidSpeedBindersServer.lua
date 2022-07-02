--[=[
	Holds binders
	@class HumanoidSpeedBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	serviceBag:GetService(require("RogueHumanoidService"))

--[=[
	@prop HumanoidSpeed Binder<HumanoidSpeed>
	@within HumanoidSpeedBindersServer
]=]
	self:Add(Binder.new("HumanoidSpeed", require("HumanoidSpeed"), serviceBag))
end)