--[=[
	@class SoundGroupServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local SoundGroupServiceClient = {}
SoundGroupServiceClient.ServiceName = "SoundGroupServiceClient"

function SoundGroupServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._serviceBag:GetService(require("SoundEffectService"))
end

function SoundGroupServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SoundGroupServiceClient