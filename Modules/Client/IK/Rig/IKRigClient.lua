--- Handles IK rigging for a humanoid
-- @classmod IKRigClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local IKRigBase = require("IKRigBase")
local IKConstants = require("IKConstants")
local IKRigAimerLocalPlayer = require("IKRigAimerLocalPlayer")

local IKRigClient = setmetatable({}, IKRigBase)
IKRigClient.ClassName = "IKRigClient"
IKRigClient.__index = IKRigClient

require("PromiseRemoteEventMixin"):Add(IKRigClient, IKConstants.REMOTE_EVENT_NAME)

function IKRigClient.new(humanoid)
	local self = setmetatable(IKRigBase.new(humanoid), IKRigClient)

	self:PromiseRemoteEvent():Then(function(remoteEvent)
		self._remoteEvent = remoteEvent or error("No remoteEvent")
		self._maid:GiveTask(self._remoteEvent.OnClientEvent:Connect(function(...)
			self:_handleRemoteEventClient(...)
		end))

		if self:GetPlayer() == Players.LocalPlayer then
			self:_setupLocalPlayer(self._remoteEvent)
		end
	end)

	return self
end

function IKRigClient:GetPositionOrNil()
	local rootPart = self._obj.RootPart
	if not rootPart then
		return nil
	end

	return rootPart.Position
end

function IKRigClient:GetLocalPlayerAimer()
	return self._aimer
end

function IKRigClient:_handleRemoteEventClient(newTarget)
	assert(typeof(newTarget) == "Vector3" or newTarget == nil)

	local torso = self:GetTorso()

	if torso then
		torso:Point(newTarget)
	end
end

function IKRigClient:_setupLocalPlayer(remoteEvent)
	self._aimer = IKRigAimerLocalPlayer.new(self, remoteEvent)
	self._maid:GiveTask(self._aimer)
end

return IKRigClient