--!strict
--[=[
	@class TieRealmService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")

local TieRealmService = {}
TieRealmService.ServiceName = "TieRealmService"

export type TieRealmService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealm: TieRealms.TieRealm,
	},
	{} :: typeof({ __index = TieRealmService })
))

function TieRealmService.Init(self: TieRealmService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	if not self._tieRealm then
		self._tieRealm = TieRealmUtils.inferTieRealm()
	end
end

--[=[
	Sets the tie realm for this service bag
]=]
function TieRealmService.SetTieRealm(self: TieRealmService, tieRealm: TieRealms.TieRealm)
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	self._tieRealm = tieRealm
end

--[=[
	Get the tie realm for this service bag
]=]
function TieRealmService.GetTieRealm(self: TieRealmService): TieRealms.TieRealm
	return self._tieRealm
end

return TieRealmService
