--!strict
--[=[
	@class TieRealmService
]=]

local require = require(script.Parent.loader).load(script)

local TieRealmUtils = require("TieRealmUtils")
local _ServiceBag = require("ServiceBag")
local _TieRealms = require("TieRealms")

local TieRealmService = {}
TieRealmService.ServiceName = "TieRealmService"

function TieRealmService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	if not self._tieRealm then
		self._tieRealm = TieRealmUtils.inferTieRealm()
	end
end

function TieRealmService:SetTieRealm(tieRealm: _TieRealms.TieRealm)
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	self._tieRealm = tieRealm
end

function TieRealmService:GetTieRealm(): _TieRealms.TieRealm
	return self._tieRealm
end

return TieRealmService