--[=[
	@class GameServiceServer
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local GameServiceServer = {}

function GameServiceServer:Init(serviceBag: ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))
	self._serviceBag:GetService(require("RagdollService"))
	self._serviceBag:GetService(require("IKService"))
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("GameTranslator"))
	self._serviceBag:GetService(require("GameBindersServer"))
end

function GameServiceServer:Start()
	self._serviceBag:GetService(require("RagdollService")):SetUnragdollAutomatically(true)
	self._serviceBag:GetService(require("RagdollService")):SetRagdollOnFall(true)
	self._serviceBag:GetService(require("RagdollService")):SetRagdollOnDeath(true)
end

return GameServiceServer
