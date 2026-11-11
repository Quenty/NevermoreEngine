--!strict
--[=[
	Holds the client binders for the death report system. Kept for callers that still retrieve binders
	through a provider; every binder here is the same singleton a [ServiceBag] hands out directly.

	:::tip
	Binders can be retrieved directly through a [ServiceBag] now, for example
	`serviceBag:GetService(require("TeamKillTrackerClient"))`.
	:::

	@client
	@deprecated 10.60.0 -- Retrieve the binders directly from the ServiceBag
	@class DeathReportBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self: BinderProvider.BinderProvider, serviceBag: ServiceBag.ServiceBag)
	--[=[
	@prop TeamKillTracker Binder<TeamKillTrackerClient>
	@within DeathReportBindersClient
]=]
	self:Add(serviceBag:GetService(require("TeamKillTrackerClient")))

	--[=[
	@prop PlayerKillTracker Binder<PlayerKillTrackerClient>
	@within DeathReportBindersClient
]=]
	self:Add(serviceBag:GetService(require("PlayerKillTrackerClient")))

	--[=[
	@prop PlayerDeathTracker Binder<PlayerDeathTrackerClient>
	@within DeathReportBindersClient
]=]
	self:Add(serviceBag:GetService(require("PlayerDeathTrackerClient")))
end)
