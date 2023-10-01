--[=[
	Holds binders
	@class HumanoidSpeedBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")

return BinderProvider.new(script.Name, function(self, serviceBag)
	serviceBag:GetService(require("RogueHumanoidService"))

--[=[
	@prop HumanoidSpeed Binder<HumanoidSpeed>
	@within HumanoidSpeedBindersServer
]=]
	self:Add(serviceBag:GetService(require("HumanoidSpeed")))
end)