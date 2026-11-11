--!strict
--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly
	@server
	@class ResetService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local PlayerUtils = require("PlayerUtils")
local Promise = require("Promise")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

local ResetService = {}
ResetService.ServiceName = "ResetService"

export type ResetProvider = (player: Player) -> Promise.Promise<...any>

export type ResetService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: Remoting.Remoting,
		_resetProviderStack: StateStack.StateStack<ResetProvider>,
	},
	{} :: typeof({ __index = ResetService })
))

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].

	@param serviceBag ServiceBag
]=]
function ResetService.Init(self: ResetService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "ResetService"))

	self._maid:GiveTask(self._remoting.ResetCharacter:Bind(function(player: Player)
		return self:PromiseResetCharacter(player)
	end))

	local defaultResetProvider: ResetProvider = function(player: Player)
		return PlayerUtils.promiseLoadCharacter(player)
	end

	self._resetProviderStack = self._maid:Add(StateStack.new(defaultResetProvider, "function"))
end

--[=[
	Pushes a reset provider onto the reset service

	@param promiseReset ResetProvider -- Reset provider
	@return () -> () -- Cleanup function to pop the provider
]=]
function ResetService.PushResetProvider(self: ResetService, promiseReset: ResetProvider): () -> ()
	assert(type(promiseReset) == "function", "Bad promiseReset")

	return self._resetProviderStack:PushState(promiseReset)
end

--[=[
	Resets the player's character using the current reset provider

	@param player Player
	@return Promise
]=]
function ResetService.PromiseResetCharacter(self: ResetService, player: Player): Promise.Promise<...any>
	assert(typeof(player) == "Instance", "Bad player")

	if not player:IsDescendantOf(game) then
		return Promise.rejected("Player is not descendant of game")
	end

	local provider = self._resetProviderStack:GetState()
	if not provider then
		return Promise.rejected("No reset provider")
	end

	return provider(player)
end

function ResetService.Destroy(self: ResetService): ()
	self._maid:DoCleaning()
end

return ResetService
