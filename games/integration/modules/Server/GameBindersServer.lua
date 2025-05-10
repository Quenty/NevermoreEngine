--[=[
	@class GameBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local PlayerHumanoidBinder = require("PlayerHumanoidBinder")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	self:Add(Binder.new("PhysicalButton", require("PhysicalButton"), serviceBag))
	self:Add(PlayerHumanoidBinder.new("LookAtButtons", require("LookAtButtons"), serviceBag))
end)