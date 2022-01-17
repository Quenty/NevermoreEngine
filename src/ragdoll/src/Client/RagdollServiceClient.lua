--[=[
	@client
	@class RagdollServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local RagdollServiceConstants = require("RagdollServiceConstants")

local Players = game:GetService("Players")

local RagdollServiceClient = {}

--[=[
	Initializes the ragdoll service on the client.
]=]
function RagdollServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._serviceBag:GetService(require("RagdollBindersClient"))

	self._screenShakeEnabled = true
end

function RagdollServiceClient:SetScreenShakeEnabled(value)
	assert(type(value) == "boolean", "Bad value")
	Players.LocalPlayer:SetAttribute(RagdollServiceConstants.SCREEN_SHAKE_ENABLED_ATTRIBUTE)
end

function RagdollServiceClient:GetScreenShakeEnabled()
	assert(self._serviceBag, "Not initialized")


	return AttributeUtils.getAttribute(Players.LocalPlayer, RagdollServiceConstants.SCREEN_SHAKE_ENABLED_ATTRIBUTE, true)
end


return RagdollServiceClient