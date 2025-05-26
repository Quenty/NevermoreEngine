--[=[
	Ragdolls the humanoid on death. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnFallClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local BindableRagdollHumanoidOnFall = require("BindableRagdollHumanoidOnFall")
local Binder = require("Binder")
local CharacterUtils = require("CharacterUtils")
local RagdollClient = require("RagdollClient")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")

local RagdollHumanoidOnFallClient = setmetatable({}, BaseObject)
RagdollHumanoidOnFallClient.ClassName = "RagdollHumanoidOnFallClient"
RagdollHumanoidOnFallClient.__index = RagdollHumanoidOnFallClient

require("PromiseRemoteEventMixin"):Add(RagdollHumanoidOnFallClient, RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME)

--[=[
	Constructs a new RagdollHumanoidOnFallClient. This module exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnFallClient
]=]
function RagdollHumanoidOnFallClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollHumanoidOnFallClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		self._ragdollLogic = self._maid:Add(BindableRagdollHumanoidOnFall.new(self._obj, self._ragdollBinder))

		self._maid:GiveTask(self._ragdollLogic.ShouldRagdoll.Changed:Connect(function()
			self:_update()
		end))
	end

	return self
end

function RagdollHumanoidOnFallClient:_update()
	if self._ragdollLogic.ShouldRagdoll.Value then
		self._ragdollBinder:BindClient(self._obj)
		self:PromiseRemoteEvent():Then(function(remoteEvent)
			remoteEvent:FireServer(true)
		end)
	end
end

return Binder.new("RagdollHumanoidOnFall", RagdollHumanoidOnFallClient)
