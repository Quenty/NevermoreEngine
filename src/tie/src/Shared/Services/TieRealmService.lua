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
		_hasExplicitTieRealm: boolean?,
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
function TieRealmService.SetTieRealm(self: TieRealmService, tieRealm: TieRealms.TieRealm): ()
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	self._tieRealm = tieRealm
	self._hasExplicitTieRealm = true
end

--[=[
	Returns whether the realm was set with [TieRealmService.SetTieRealm] rather than inferred.

	[RunService] reports the server even when the game is not running, such as in Studio edit mode
	or a headless test. A service whose server behavior is unsafe there can keep its own inference
	unless the bag was told a realm.

	@return boolean
]=]
function TieRealmService.HasExplicitTieRealm(self: TieRealmService): boolean
	return self._hasExplicitTieRealm == true
end

--[=[
	Get the tie realm for this service bag
]=]
function TieRealmService.GetTieRealm(self: TieRealmService): TieRealms.TieRealm
	return self._tieRealm
end

return TieRealmService
