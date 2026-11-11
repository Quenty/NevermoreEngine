--!strict
--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly.

	Automatically sets itself ot the ResetButtonCallback upon initialization.

	The reset button may be disabled by pushing onto the disable stack.

	```lua
	local cancel = resetServiceClient:PushDisable()
	-- ... reset button is hidden ...
	cancel()
	```

	@client
	@class ResetServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtils = require("CharacterUtils")
local CoreGuiUtils = require("CoreGuiUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

local RETRY_ATTEMPTS = 3
local INITIAL_WAIT_TIME = 1

local ResetServiceClient = {}
ResetServiceClient.ServiceName = "ResetServiceClient"

export type ResetServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: Remoting.Remoting,
		_resetBindable: BindableEvent,
		_disabledStack: StateStack.StateStack<boolean>,
	},
	{} :: typeof({ __index = ResetServiceClient })
))

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].

	@param serviceBag ServiceBag
]=]
function ResetServiceClient.Init(self: ResetServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "ResetService"))

	self._resetBindable = self._maid:Add(Instance.new("BindableEvent"))
	self._maid:GiveTask(self._resetBindable.Event:Connect(function()
		self:PromiseResetCharacter()
	end))

	self._disabledStack = self._maid:Add(StateStack.new(false, "boolean"))

	self._maid:GiveTask(self._disabledStack:Observe():Subscribe(function(disabled)
		self:_updateResetButtonCallback(disabled)
	end))
end

--[=[
	Pushes a disable state onto the reset service, which removes the reset button
	for the local player for as long as the state is held.

	@return function -- Function to cancel the disable
]=]
function ResetServiceClient.PushDisable(self: ResetServiceClient): () -> ()
	assert(self._disabledStack, "Not initialized")

	return self._disabledStack:PushState(true)
end

--[=[
	Returns whether the reset button is currently disabled

	@return boolean
]=]
function ResetServiceClient.IsDisabled(self: ResetServiceClient): boolean
	assert(self._disabledStack, "Not initialized")

	return self._disabledStack:GetState()
end

--[=[
	Observes whether the reset button is currently disabled

	@return Observable<boolean>
]=]
function ResetServiceClient.ObserveIsDisabled(self: ResetServiceClient): Observable.Observable<boolean>
	assert(self._disabledStack, "Not initialized")

	return self._disabledStack:Observe()
end

function ResetServiceClient._updateResetButtonCallback(self: ResetServiceClient, disabled: boolean): ()
	-- SetCore takes `false` to remove the reset button entirely, and the bindable to restore it.
	local callback: any = if disabled then false else self._resetBindable

	local promise = CoreGuiUtils.promiseRetrySetCore(RETRY_ATTEMPTS, INITIAL_WAIT_TIME, "ResetButtonCallback", callback)

	-- Named task: a newer state supersedes an in-flight retry instead of racing it.
	self._maid._setCore = promise

	promise:Catch(function(err)
		if err ~= nil then
			warn(string.format("[ResetServiceClient] - Failed to SetCore due to %q", tostring(err)))
		end
	end)
end

--[=[
	Requests the player's character resets

	@return Promise
]=]
function ResetServiceClient.RequestResetCharacter(self: ResetServiceClient): Promise.Promise<...any>
	return self:PromiseResetCharacter()
end

--[=[
	Kills the local character and requests the server reset it

	@return Promise
]=]
function ResetServiceClient.PromiseResetCharacter(self: ResetServiceClient): Promise.Promise<...any>
	local localPlayer = Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()
	if localPlayer then
		local humanoid = CharacterUtils.getPlayerHumanoid(localPlayer)
		if humanoid then
			humanoid.Health = 0
		end
	end

	return self._maid:GivePromise(self._remoting.ResetCharacter:PromiseInvokeServer())
end

function ResetServiceClient.Destroy(self: ResetServiceClient): ()
	self._maid:DoCleaning();
	(self :: any)._maid = nil
end

return ResetServiceClient
