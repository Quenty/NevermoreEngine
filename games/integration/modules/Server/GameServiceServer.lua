---
-- @module GameServiceServer
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local GameServiceServer = {}

function GameServiceServer:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))
	self._serviceBag:GetService(require("RagdollBindersServer"))
	self._serviceBag:GetService(require("IKService"))

	-- Internal
	self._serviceBag:GetService(require("GameBindersServer"))
end

return GameServiceServer