--!strict
--[=[
	Initializes the RagdollService on the client.

	@client
	@class RagdollServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local AttributeValue = require("AttributeValue")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local RagdollServiceClient = {}
RagdollServiceClient.ServiceName = "RagdollServiceClient"

export type RagdollServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_screenShakeEnabled: AttributeValue.AttributeValue<boolean>?,
	},
	{} :: typeof({ __index = RagdollServiceClient })
))

--[=[
	Initializes the ragdoll service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function RagdollServiceClient.Init(self: RagdollServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("Motor6DServiceClient"))
	self._serviceBag:GetService(require("CameraStackService"))

	-- Internal
	self._serviceBag:GetService((require :: any)("RagdollClient"))
	self._serviceBag:GetService((require :: any)("RagdollableClient"))
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnDeathClient"))
	self._serviceBag:GetService((require :: any)("RagdollHumanoidOnFallClient"))
	self._serviceBag:GetService((require :: any)("RagdollCameraShakeClient"))
	self._serviceBag:GetService((require :: any)("RagdollBindersClient"))
end

-- Resolved lazily rather than in Init so a headless boot (no LocalPlayer, and the PlayerMock
-- designated between Init and Start) never errors; both realms resolve on first use.
function RagdollServiceClient._getScreenShakeEnabled(self: RagdollServiceClient): AttributeValue.AttributeValue<boolean>
	local screenShakeEnabled = self._screenShakeEnabled
	if screenShakeEnabled then
		return screenShakeEnabled
	end

	local localPlayer = assert(Players.LocalPlayer or PlayerMock.getMockedLocalPlayer(), "No local player")
	local created = AttributeValue.new(localPlayer, "RagdollScreenShakeEnabled", true)
	self._screenShakeEnabled = created
	return created
end

--[=[
	Sets screen shake enabled for the local player
	@param value boolelan
]=]
function RagdollServiceClient.SetScreenShakeEnabled(self: RagdollServiceClient, value: boolean): ()
	assert(type(value) == "boolean", "Bad value")

	self:_getScreenShakeEnabled().Value = value
end

--[=[
	Returns wheher screenshake is enabled.
	@return boolean
]=]
function RagdollServiceClient.GetScreenShakeEnabled(self: RagdollServiceClient): boolean
	assert(self._serviceBag, "Not initialized")

	return self:_getScreenShakeEnabled().Value
end

return RagdollServiceClient
