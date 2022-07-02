--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly.

	Automatically sets itself ot the ResetButtonCallback upon initialization.

	@client
	@class ResetServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local ResetServiceConstants = require("ResetServiceConstants")
local CoreGuiUtils = require("CoreGuiUtils")
local Maid = require("Maid")

local RETRY_ATTEMPTS = 3
local INITIAL_WAIT_TIME = 1

local ResetServiceClient = {}

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].
]=]
function ResetServiceClient:Init()
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()

	self._resetBindable = Instance.new("BindableEvent")
	self._resetBindable.Event:connect(function()
		self:RequestResetCharacter()
	end)
	self._maid:GiveTask(self._resetBindable)

	CoreGuiUtils.promiseRetrySetCore(RETRY_ATTEMPTS, INITIAL_WAIT_TIME, "ResetButtonCallback", self._resetBindable)
		:Catch(function(err)
			warn(("[ResetServiceClient] - Failed to SetCore due to %q"):format(tostring(err)))
		end)
end

--[=[
	Requests the player's character resets
]=]
function ResetServiceClient:RequestResetCharacter()
	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	self._promiseRemoteEvent():Then(function(remoteEvent)
		remoteEvent:FireServer()
	end)
end

function ResetServiceClient:_promiseRemoteEvent()
	return self._maid:GivePromise(PromiseGetRemoteEvent(ResetServiceConstants.REMOTE_EVENT_NAME))
end

function ResetServiceClient:Destroy()
	self._maid:DoCleaning()
	self._maid = nil
end

return ResetServiceClient