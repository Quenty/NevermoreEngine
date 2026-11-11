--!strict
--[=[
	Holds the server binders for the death report system. Kept for callers that still retrieve binders
	through a provider; every binder here is the same singleton a [ServiceBag] hands out directly.

	:::tip
	Binders can be retrieved directly through a [ServiceBag] now, for example
	`serviceBag:GetService(require("TeamKillTracker"))`.
	:::

	@server
	@deprecated 10.60.0 -- Retrieve the binders directly from the ServiceBag
	@class DeathReportBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local ServiceBag = require("ServiceBag")

return BinderProvider.new(script.Name, function(self: BinderProvider.BinderProvider, serviceBag: ServiceBag.ServiceBag)
	--[=[
	@prop TeamKillTracker Binder<TeamKillTracker>
	@within DeathReportBindersServer
]=]
	self:Add(serviceBag:GetService(require("TeamKillTracker")))

	--[=[
	@prop PlayerKillTracker Binder<PlayerKillTracker>
	@within DeathReportBindersServer
]=]
	self:Add(serviceBag:GetService(require("PlayerKillTracker")))

	--[=[
	@prop PlayerDeathTracker Binder<PlayerDeathTracker>
	@within DeathReportBindersServer
]=]
	self:Add(serviceBag:GetService(require("PlayerDeathTracker")))
end)
