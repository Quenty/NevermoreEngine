--[=[
	@class TieRealmService
]=]

local require = require(script.Parent.loader).load(script)

local TieRealmUtils = require("TieRealmUtils")

local TieRealmService = {}
TieRealmService.ServiceName = "TieRealmService"

function TieRealmService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	if not self._tieRealm then
		self._tieRealm = TieRealmUtils.inferTieRealm()
	end
end

function TieRealmService:SetTieRealm(tieRealm)
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	self._tieRealm = tieRealm
end

function TieRealmService:GetTieRealm()
	return self._tieRealm
end

return TieRealmService