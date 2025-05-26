--[=[
	@class GameBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	self:Add(Binder.new("PhysicalButton", require("PhysicalButtonClient"), serviceBag))
	self:Add(Binder.new("LookAtButtons", require("LookAtButtonsClient"), serviceBag))
end)
