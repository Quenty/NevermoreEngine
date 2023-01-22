--[=[
	@class DeathReportBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(script.Name, function(self, serviceBag)
	-- Stats
	self:Add(Binder.new("TeamKillTracker", require("TeamKillTrackerClient"), serviceBag))
	self:Add(Binder.new("PlayerKillTracker", require("PlayerKillTrackerClient"), serviceBag))
	self:Add(Binder.new("PlayerDeathTracker", require("PlayerDeathTrackerClient"), serviceBag))
end)