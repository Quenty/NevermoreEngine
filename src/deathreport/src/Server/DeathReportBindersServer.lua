--[=[
	@class DeathReportBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")

return BinderProvider.new(script.Name, function(self, serviceBag)
	-- Stats
	self:Add(Binder.new("TeamKillTracker", require("TeamKillTracker"), serviceBag))
	self:Add(Binder.new("PlayerKillTracker", require("PlayerKillTracker"), serviceBag))
	self:Add(Binder.new("PlayerDeathTracker", require("PlayerDeathTracker"), serviceBag))
end)
