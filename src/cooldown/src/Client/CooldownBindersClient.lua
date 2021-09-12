--- Holds binders
-- @classmod CooldownBindersClient
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")
local TimeSyncService = require("TimeSyncService")

return BinderProvider.new(function(self, serviceBag)
	serviceBag:GetService(TimeSyncService)

	self:Add(Binder.new("Cooldown", require("CooldownClient"), serviceBag))
end)