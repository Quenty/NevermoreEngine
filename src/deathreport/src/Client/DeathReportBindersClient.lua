--[=[
	@class DeathReportBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	-- Stats
	self:Add(Binder.new("TeamKillTracker", require("TeamKillTrackerClient"), serviceBag))
	self:Add(Binder.new("PlayerKillTracker", require("PlayerKillTrackerClient"), serviceBag))
	self:Add(Binder.new("PlayerDeathTracker", require("PlayerDeathTrackerClient"), serviceBag))
end)
