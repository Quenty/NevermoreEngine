--!strict
--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly.

	Automatically sets itself ot the ResetButtonCallback upon initialization.

	@client
	@class ResetServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreGuiUtils = require("CoreGuiUtils")
local Maid = require("Maid")
local Remoting = require("Remoting")
local Promise = require("Promise")

local RETRY_ATTEMPTS = 3
local INITIAL_WAIT_TIME = 1

local ResetServiceClient = {}
ResetServiceClient.ServiceName = "ResetServiceClient"

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].
]=]
function ResetServiceClient:Init()
	assert(not self._maid, "Already initialized")
	self._maid = Maid.new()

	-- Configure
	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "ResetService"))

	self._resetBindable = self._maid:Add(Instance.new("BindableEvent"))
	self._maid:GiveTask(self._resetBindable.Event:Connect(function()
		self:PromiseResetCharacter()
	end))

	self._maid
		:GivePromise(
			CoreGuiUtils.promiseRetrySetCore(
				RETRY_ATTEMPTS,
				INITIAL_WAIT_TIME,
				"ResetButtonCallback",
				self._resetBindable
			)
		)
		:Catch(function(err)
			warn(string.format("[ResetServiceClient] - Failed to SetCore due to %q", tostring(err)))
		end)
end

--[=[
	Requests the player's character resets
]=]
function ResetServiceClient:RequestResetCharacter(): Promise.Promise<()>
	return self:PromiseResetCharacter()
end

function ResetServiceClient:PromiseResetCharacter(): Promise.Promise<()>
	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	return self._maid:GivePromise(self._remoting.ResetCharacter:PromiseInvokeServer())
end

function ResetServiceClient:Destroy()
	self._maid:DoCleaning();
	(self :: any)._maid = nil
end

return ResetServiceClient