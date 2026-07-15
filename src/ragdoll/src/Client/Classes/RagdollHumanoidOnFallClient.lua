--!strict
--[=[
	Ragdolls the humanoid on fall. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnFallClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local BindableRagdollHumanoidOnFall = require("BindableRagdollHumanoidOnFall")
local Binder = require("Binder")
local CharacterUtils = require("CharacterUtils")
local Promise = require("Promise")
local RagdollClient = require("RagdollClient")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")
local ServiceBag = require("ServiceBag")

local RagdollHumanoidOnFallClient = setmetatable({}, BaseObject)
RagdollHumanoidOnFallClient.ClassName = "RagdollHumanoidOnFallClient"
RagdollHumanoidOnFallClient.__index = RagdollHumanoidOnFallClient

export type RagdollHumanoidOnFallClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_ragdollBinder: Binder.Binder<RagdollClient.RagdollClient>,
			_ragdollLogic: BindableRagdollHumanoidOnFall.BindableRagdollHumanoidOnFall?,
			-- PromiseRemoteEventMixin surface (injected at runtime)
			_remoteEventName: string,
			PromiseRemoteEvent: (self: any) -> Promise.Promise<RemoteEvent>,
		},
		{} :: typeof({ __index = RagdollHumanoidOnFallClient })
	))
	& BaseObject.BaseObject

require("PromiseRemoteEventMixin"):Add(RagdollHumanoidOnFallClient, RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME)

--[=[
	Constructs a new RagdollHumanoidOnFallClient. This module exports a [Binder].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnFallClient
]=]
function RagdollHumanoidOnFallClient.new(
	humanoid: Humanoid,
	serviceBag: ServiceBag.ServiceBag
): RagdollHumanoidOnFallClient
	local self: RagdollHumanoidOnFallClient = setmetatable(BaseObject.new(humanoid) :: any, RagdollHumanoidOnFallClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	local player = CharacterUtils.getPlayerFromCharacter(humanoid)
	if player == Players.LocalPlayer then
		local ragdollLogic = self._maid:Add(BindableRagdollHumanoidOnFall.new(humanoid, self._ragdollBinder))
		self._ragdollLogic = ragdollLogic

		self._maid:GiveTask(ragdollLogic.ShouldRagdoll.Changed:Connect(function()
			self:_update()
		end))
	end

	return self
end

function RagdollHumanoidOnFallClient._update(self: RagdollHumanoidOnFallClient): ()
	local ragdollLogic = self._ragdollLogic
	if ragdollLogic and ragdollLogic.ShouldRagdoll.Value then
		local obj = assert(self._obj, "No obj")
		self._ragdollBinder:BindClient(obj)
		self:PromiseRemoteEvent():Then(function(remoteEvent)
			remoteEvent:FireServer(true)
		end)
	end
end

return Binder.new(
		"RagdollHumanoidOnFall",
		RagdollHumanoidOnFallClient :: any
	) :: Binder.Binder<RagdollHumanoidOnFallClient>
