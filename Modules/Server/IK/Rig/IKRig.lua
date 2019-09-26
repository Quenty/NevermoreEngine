--- Serverside implementation of IKRig
-- @classmod IKRig
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local IKConstants = require("IKConstants")
local CharacterUtil = require("CharacterUtil")

local IKRig = setmetatable({}, BaseObject)
IKRig.ClassName = "IKRig"
IKRig.__index = IKRig

function IKRig.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), IKRig)

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

function IKRig:SetRigTarget(target)
	assert(typeof(target) == "Vector3")

	self._target = target
	self._remoteEvent:FireAllClients(target)
end

function IKRig:_onServerEvent(player, target)
	assert(player == CharacterUtil.GetPlayerFromCharacter(self._obj))
	assert(typeof(target) == "Vector3")

	self._target = target

	-- Do replication
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= player then
			self._remoteEvent:FireClient(other, target)
		end
	end
end

return IKRig