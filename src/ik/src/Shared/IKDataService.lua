--[=[
	@class IKDataService
]=]

local require = require(script.Parent.loader).load(script)

local IKRigInterface = require("IKRigInterface")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")

local IKDataService = {}
IKDataService.ServiceName = "IKDataService"

function IKDataService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._tieRealmService = self._serviceBag:GetService(TieRealmService)
end

function IKDataService:PromiseRig(humanoid: Humanoid)
	return IKRigInterface:Promise(humanoid, self._tieRealmService:GetTieRealm())
end

function IKDataService:ObserveRig(humanoid: Humanoid)
	return IKRigInterface:Observe(humanoid, self._tieRealmService:GetTieRealm())
end

function IKDataService:ObserveRigBrio(humanoid: Humanoid)
	return IKRigInterface:ObserveBrio(humanoid, self._tieRealmService:GetTieRealm())
end

return IKDataService
