--[=[
	@class GameServiceServer
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local GameServiceServer = {}

function GameServiceServer:Init(serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("TimeSyncService"))
	self._serviceBag:GetService(require("RagdollService"))
	self._serviceBag:GetService(require("IKService"))

	-- Internal
	self._serviceBag:GetService(require("GameTranslator"))
	self._serviceBag:GetService(require("GameBindersServer"))
end

return GameServiceServer