--!strict
--[=[
	Holds binders
	@class HumanoidSpeedBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	serviceBag:GetService(require("RogueHumanoidServiceClient"))

	--[=[
	@prop HumanoidSpeed Binder<HumanoidSpeedClient>
	@within HumanoidSpeedBindersClient
]=]
	self:Add(serviceBag:GetService(require("HumanoidSpeedClient")))
end)
