--- Handles the replication of inverse kinematics (IK) from clients to servers
-- @classmod IKService

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CharacterUtils = require("CharacterUtils")
local IKConstants = require("IKConstants")
local Binder = require("Binder")
local Maid = require("Maid")
local HumanoidTracker = require("HumanoidTracker")
local promiseBoundClass = require("promiseBoundClass")

local SERVER_UPDATE_RATE = 1/10

local IKService = {}

function IKService:Init()
	self._maid = Maid.new()

	self._ikRigBinder = Binder.new(IKConstants.COLLECTION_SERVICE_TAG, require("IKRig"))
	self._ikRigBinder:Init()

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayer(player)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	for _, player in pairs(Players:GetPlayers()) do
		self:_handlePlayer(player)
	end

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_updateStepped()
	end))
end

function IKService:GetRig(humanoid)
	return self._ikRigBinder:Bind(humanoid)
end

function IKService:PromiseRig(maid, humanoid)
	assert(maid)
	assert(typeof(humanoid) == "Instance")

	local promise = promiseBoundClass(self._ikRigBinder, humanoid)
	maid:GiveTask(promise)
	return promise
end

function IKService:RemoveRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	self._ikRigBinder:Unbind(humanoid)
end

function IKService:UpdateServerRigTarget(humanoid, target)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))
	assert(typeof(target) == "Vector3")

	local serverRig = self._ikRigBinder:Bind(humanoid)
	if not serverRig then
		warn("[IKService.UpdateServerRigTarget] - No serverRig")
		return
	end

	serverRig:SetRigTarget(target)
end

function IKService:_onServerEvent(player, target)
	assert(typeof(target) == "Vector3")

	local humanoid = CharacterUtils.getAlivePlayerHumanoid(player)
	if not humanoid then
		return
	end
end

function IKService:_handlePlayerRemoving(player)
	self._maid[player] = nil
end

function IKService:_handlePlayer(player)
	local maid = Maid.new()

	local humanoidTracker = HumanoidTracker.new(player)
	maid:GiveTask(humanoidTracker)

	maid:GiveTask(humanoidTracker.AliveHumanoid.Changed:Connect(function(new, old)
		if old then
			self._ikRigBinder:Unbind(old)
		end
		if new then
			self._ikRigBinder:Bind(new)
		end
	end))

	if humanoidTracker.AliveHumanoid.Value then
		self._ikRigBinder:Bind(humanoidTracker.AliveHumanoid.Value)
	end

	self._maid[player] = maid
end

function IKService:_updateStepped()
	debug.profilebegin("IKUpdateServer")

	for _, rig in pairs(self._ikRigBinder:GetAll()) do
		debug.profilebegin("RigUpdateServer")

		local lastUpdateTime = rig:GetLastUpdateTime()
		if (tick() - lastUpdateTime) >= SERVER_UPDATE_RATE then
			rig:Update() -- Update actual rig
		else
			rig:UpdateTransformOnly()
		end

		debug.profileend()
	end
	debug.profileend()
end

return IKService