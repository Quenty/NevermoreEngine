--- Handles the replication of inverse kinematics (IK) from clients to servers
-- @classmod IKService

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local CharacterUtil = require("CharacterUtil")
local GetRemoteEvent = require("GetRemoteEvent")
local IKConstants = require("IKConstants")

local IKService = {}

function IKService:Init()
	self._remoteEvent = GetRemoteEvent(IKConstants.REMOTE_EVENT_NAME)
	self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_onServerEvent(...)
	end)
end

function IKService:_onServerEvent(player, target)
	assert(typeof(target) == "Vector3")

	local humanoid = CharacterUtil.GetAlivePlayerHumanoid(player)
	if not humanoid then
		return
	end

	-- Do replication
	for _, other in pairs(Players:GetPlayers()) do
		if other ~= player then
			self._remoteEvent:FireClient(other, "UpdateRig", humanoid, target)
		end
	end
end

function IKService:RemoveServerRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	self._remoteEvent:FireAllClients("RemoveRig", humanoid)
end

function IKService:UpdateServerRigTarget(humanoid, target)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))
	assert(typeof(target) == "Vector3")

	self._remoteEvent:FireAllClients("UpdateRig", humanoid, target)
end

return IKService