--- Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly
-- @module ResetServiceClient
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PromiseGetRemoteEvent = require("PromiseGetRemoteEvent")
local ResetServiceConstants = require("ResetServiceConstants")
local CoreGuiUtils = require("CoreGuiUtils")

local RETRY_ATTEMPTS = 3
local INITIAL_WAIT_TIME = 1

local ResetServiceClient = {}

function ResetServiceClient:Init()
	assert(not self._promiseRemoteEvent, "Already initialized")

	self._promiseRemoteEvent = PromiseGetRemoteEvent(ResetServiceConstants.REMOTE_EVENT_NAME)

	local resetBindable = Instance.new("BindableEvent")
	resetBindable.Event:connect(function()
		self:RequestResetCharacter()
	end)

	CoreGuiUtils.promiseRetrySetCore(RETRY_ATTEMPTS, INITIAL_WAIT_TIME, "ResetButtonCallback", resetBindable)
		:Catch(function(err)
			warn(("[ResetServiceClient] - Failed to SetCore due to %q"):format(tostring(err)))
		end)
end

function ResetServiceClient:RequestResetCharacter()
	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	self._promiseRemoteEvent:Then(function(remoteEvent)
		remoteEvent:FireServer()
	end)
end

return ResetServiceClient