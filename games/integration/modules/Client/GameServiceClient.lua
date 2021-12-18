---
-- @module GameServiceClient
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local GameServiceClient = {}

function GameServiceClient:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))
	self._serviceBag:GetService(require("RagdollBindersClient"))
	self._serviceBag:GetService(require("IKServiceClient"))
	self._serviceBag:GetService(require("CameraStackService"))

	--Internal
	self._serviceBag:GetService(require("GameBindersClient"))
	self._serviceBag:GetService(require("GameTranslator"))
end

return GameServiceClient