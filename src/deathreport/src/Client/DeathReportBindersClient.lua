--!strict
--[=[
	@class DeathReportBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderProvider = require("BinderProvider")
local PlayerDeathTrackerClient = require("PlayerDeathTrackerClient")
local PlayerKillTrackerClient = require("PlayerKillTrackerClient")
local ServiceBag = require("ServiceBag")
local TeamKillTrackerClient = require("TeamKillTrackerClient")

return BinderProvider.new(script.Name, function(self, serviceBag: ServiceBag.ServiceBag)
	-- Stats
	self:Add(Binder.new("TeamKillTracker", TeamKillTrackerClient :: any, serviceBag))
	self:Add(Binder.new("PlayerKillTracker", PlayerKillTrackerClient :: any, serviceBag))
	self:Add(Binder.new("PlayerDeathTracker", PlayerDeathTrackerClient :: any, serviceBag))
end)
