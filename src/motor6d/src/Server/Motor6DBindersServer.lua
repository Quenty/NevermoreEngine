--[=[
	@class Motor6DBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Motor6DStack", require("Motor6DStack"), serviceBag))
	self:Add(PlayerHumanoidBinder.new("Motor6DStackHumanoid", require("Motor6DStackHumanoid"), serviceBag))
end)