--[=[
	Should be bound via [RagdollBindersClient].

	@client
	@class RagdollableClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local RagdollableConstants = require("RagdollableConstants")
local CharacterUtils = require("CharacterUtils")
local RagdollRigging = require("RagdollRigging")
local HumanoidAnimatorUtils = require("HumanoidAnimatorUtils")
local Maid = require("Maid")
local RagdollBindersClient = require("RagdollBindersClient")
local RagdollUtils = require("RagdollUtils")
-- local AttributeUtils = require("AttributeUtils")

local RagdollableClient = setmetatable({}, BaseObject)
RagdollableClient.ClassName = "RagdollableClient"
RagdollableClient.__index = RagdollableClient

require("PromiseRemoteEventMixin"):Add(RagdollableClient, RagdollableConstants.REMOTE_EVENT_NAME)

--[=[
	Constructs a new RagdollableClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollableClient
]=]
function RagdollableClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollableClient)

	self._ragdollBinder = serviceBag:GetService(RagdollBindersClient).Ragdoll

	self._player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if self._player == Players.LocalPlayer then
		self:PromiseRemoteEvent():Then(function(remoteEvent)
			self._localPlayerRemoteEvent = remoteEvent or error("No remoteEvent")

			self:_setupLocal()
		end)

		-- For fast debugging
		-- self._maid:GiveTask(AttributeUtils.bindToBinder(self._obj, "Ragdoll", self._ragdollBinder))
	else
		self:_setupLocal()
	end

	return self
end

function RagdollableClient:_setupLocal()
	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj, function()
		self:_onRagdollChanged()
	end))
	self:_onRagdollChanged()
end

function RagdollableClient:_onRagdollChanged()
	if self._ragdollBinder:Get(self._obj) then
		self._maid._ragdoll = self:_ragdollLocal()

		if self._localPlayerRemoteEvent then
			-- Tell the server that we started simulating our ragdoll
			self._localPlayerRemoteEvent:FireServer(true)
		end
	else
		self._maid._ragdoll = nil

		if self._localPlayerRemoteEvent then
			-- Let server know to reset!
			self._localPlayerRemoteEvent:FireServer(false)
		end
	end
end

function RagdollableClient:_ragdollLocal()
	local maid = Maid.new()

	-- Really hard to infer whether or not we're the network owner, so we just try to do this for every single one.

	-- Hopefully these are already created. Intent here is to reset friction. If not, the friction
	-- should be good.
	RagdollRigging.configureRagdollJoints(false, self._obj.Parent, self._obj.RigType)

	maid:GiveTask(RagdollUtils.setupState(self._obj))
	maid:GiveTask(RagdollUtils.setupMotors(self._obj))
	maid:GiveTask(RagdollUtils.setupHead(self._obj))

	-- Do this after we setup motors
	HumanoidAnimatorUtils.stopAnimations(self._obj, 0)

	maid:GiveTask(self._obj.AnimationPlayed:Connect(function(track)
		track:Stop(0)
	end))

	maid:GiveTask(RagdollUtils.preventAnimationTransformLoop(self._obj))

	return maid
end

return RagdollableClient