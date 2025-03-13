--[=[
	@class GameServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local GameServiceClient = {}
GameServiceClient.ServiceName = "GameServiceClient"

function GameServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))
	self._serviceBag:GetService(require("RagdollServiceClient"))
	self._serviceBag:GetService(require("IKServiceClient"))
	self._serviceBag:GetService(require("CameraStackService"))

	--Internal
	self._serviceBag:GetService(require("GameBindersClient"))
	self._serviceBag:GetService(require("GameTranslator"))
end

return GameServiceClient