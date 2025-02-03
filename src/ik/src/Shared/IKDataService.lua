--[=[
	@class IKDataService
]=]

local require = require(script.Parent.loader).load(script)

local IKRigInterface = require("IKRigInterface")
local TieRealmService = require("TieRealmService")

local IKDataService = {}
IKDataService.ServiceName = "IKDataService"

function IKDataService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._tieRealmService = self._serviceBag:GetService(TieRealmService)
end

function IKDataService:PromiseRig(humanoid)
	return IKRigInterface:Promise(humanoid, self._tieRealmService:GetTieRealm())
end

function IKDataService:ObserveRig(humanoid)
	return IKRigInterface:Observe(humanoid, self._tieRealmService:GetTieRealm())
end

function IKDataService:ObserveRigBrio(humanoid)
	return IKRigInterface:ObserveBrio(humanoid, self._tieRealmService:GetTieRealm())
end

return IKDataService