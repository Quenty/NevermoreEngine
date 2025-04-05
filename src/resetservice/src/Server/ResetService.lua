--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly
	@server
	@class ResetService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remoting = require("Remoting")
local Maid = require("Maid")
local StateStack = require("StateStack")
local PlayerUtils = require("PlayerUtils")
local Promise = require("Promise")

local ResetService = {}
ResetService.ServiceName = "ResetService"

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].
]=]
function ResetService:Init()
	assert(not self._remoteEvent, "Already initialized")
	self._maid = Maid.new()

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "ResetService"))

	self._maid:GiveTask(self._remoting.ResetCharacter:Bind(function(player)
		return self:PromiseResetCharacter(player)
	end))

	self._resetProviderStack = self._maid:Add(StateStack.new(function(player)
		return PlayerUtils.promiseLoadCharacter(player)
	end, "function"))
end

--[=[
	Pushes a reset provider onto the reset service

	@param promiseReset function -- Reset provider
	@return MaidTask
]=]
function ResetService:PushResetProvider(promiseReset: () -> ())
	assert(type(promiseReset) == "function", "Bad promiseReset")

	return self._resetProviderStack:PushState(promiseReset)
end

function ResetService:PromiseResetCharacter(player)
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

function ResetService:Destroy()
	self._maid:DoCleaning()
end

return ResetService