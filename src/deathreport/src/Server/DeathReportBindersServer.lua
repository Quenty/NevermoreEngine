--!strict
--[=[
	@class DeathReportBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerKillTracker = require("PlayerKillTracker")
local ServiceBag = require("ServiceBag")
local TeamKillTracker = require("TeamKillTracker")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	-- Stats
	self:Add(Binder.new("TeamKillTracker", TeamKillTracker :: any, serviceBag))
	self:Add(Binder.new("PlayerKillTracker", PlayerKillTracker :: any, serviceBag))
	self:Add(Binder.new("PlayerDeathTracker", PlayerDeathTracker :: any, serviceBag))
end)
