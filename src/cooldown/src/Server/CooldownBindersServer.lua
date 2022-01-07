--[=[
	Holds binders for [Cooldown].
	@class CooldownBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local TimeSyncService = require("TimeSyncService")

return BinderProvider.new(function(self, serviceBag)
	serviceBag:GetService(TimeSyncService)

--[=[
	@prop Cooldown Binder<Cooldown>
	@within CooldownBindersServer
]=]
	self:Add(Binder.new("Cooldown", require("Cooldown"), serviceBag))
end)