--[=[
	Handles IK rigging for a humanoid
	@class IKRigClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local IKRigBase = require("IKRigBase")
local IKConstants = require("IKConstants")
local IKRigAimerLocalPlayer = require("IKRigAimerLocalPlayer")
local Binder = require("Binder")

local IKRigClient = setmetatable({}, IKRigBase)
IKRigClient.ClassName = "IKRigClient"
IKRigClient.__index = IKRigClient

require("PromiseRemoteEventMixin"):Add(IKRigClient, IKConstants.REMOTE_EVENT_NAME)

function IKRigClient.new(humanoid, serviceBag)
	local self = setmetatable(IKRigBase.new(humanoid, serviceBag), IKRigClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	if self:GetPlayer() == Players.LocalPlayer then
		self:_setupLocalPlayer(self._remoteEvent)
	end

	self:PromiseRemoteEvent():Then(function(remoteEvent)
		self._remoteEvent = assert(remoteEvent, "No remoteEvent")

		self._maid:GiveTask(self._remoteEvent.OnClientEvent:Connect(function(...)
			self:_handleRemoteEventClient(...)
		end))

		if self._localPlayerAimer then
			self._localPlayerAimer:SetRemoteEvent(self._remoteEvent)
		end
	end)

	return self
end

--[=[
	Retrieves where the IK rig's position is, if it exists

	@return Vector3?
]=]
function IKRigClient:GetPositionOrNil()
	local rootPart = self._obj.RootPart
	if not rootPart then
		return nil
	end

	return rootPart.Position
end

--[=[
	Retrieves the local player aimer if it exists

	@return IKRigAimerLocalPlayer?
]=]
function IKRigClient:GetLocalPlayerAimer()
	return self._localPlayerAimer
end

--[=[
	Returns where the rig is looking at

	@return Vector3?
]=]
function IKRigClient:GetTarget()
	if self._localPlayerAimer then
		return self._localPlayerAimer:GetAimPosition()
	end

	return self._target
end


function IKRigClient:_handleRemoteEventClient(newTarget)
	assert(typeof(newTarget) == "Vector3" or newTarget == nil, "Bad newTarget")

	local torso = self:GetTorso()

	if torso then
		torso:Point(newTarget)
	end

	self._target = newTarget
end

function IKRigClient:_setupLocalPlayer(remoteEvent)
	self._localPlayerAimer = IKRigAimerLocalPlayer.new(self._serviceBag, self, remoteEvent)
	self._maid:GiveTask(self._localPlayerAimer)
end

return Binder.new("IKRig", IKRigClient)