--- Serverside implementation of IKRig
-- @classmod IKRig
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local IKRigBase = require("IKRigBase")
local IKConstants = require("IKConstants")
local CharacterUtils = require("CharacterUtils")

local IKRig = setmetatable({}, IKRigBase)
IKRig.ClassName = "IKRig"
IKRig.__index = IKRig

function IKRig.new(humanoid)
	local self = setmetatable(IKRigBase.new(humanoid), IKRig)

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = IKConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_onServerEvent(...)
	end))

	self._target = nil

	return self
end

function IKRig:GetTarget()
	return self._target
end

function IKRig:SetRigTarget(target)
	assert(typeof(target) == "Vector3" or target == nil)

	self._target = target

	local torso = self:GetTorso()
	if torso then
		torso:Point(self._target)
	end

	self._remoteEvent:FireAllClients(target)
end

function IKRig:_onServerEvent(player, target)
	assert(player == CharacterUtils.getPlayerFromCharacter(self._obj))
	assert(typeof(target) == "Vector3" or target == nil)

	self._target = target

	local torso = self:GetTorso()
	if torso then
		torso:Point(self._target)
	end

	-- Do replication
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= player then
			self._remoteEvent:FireClient(other, target) -- target may nil
		end
	end
end

return IKRig