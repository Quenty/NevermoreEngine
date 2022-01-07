--[=[
	Holds binders for [Cooldown].
	@class CooldownBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local TimeSyncService = require("TimeSyncService")

return BinderProvider.new(function(self, serviceBag)
	serviceBag:GetService(TimeSyncService)

--[=[
	@prop Cooldown Binder<CooldownClient>
	@within CooldownBindersClient
]=]
	self:Add(Binder.new("Cooldown", require("CooldownClient"), serviceBag))
end)