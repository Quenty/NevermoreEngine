--- Handles IK for local client
-- @classmod IKServiceClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local IKConstants = require("IKConstants")
local Maid = require("Maid")
local Binder = require("Binder")
local IKRigUtils = require("IKRigUtils")

local IKServiceClient = {}

function IKServiceClient:Init()
	self._maid = Maid.new()
	self._ikRigBinder = Binder.new(IKConstants.COLLECTION_SERVICE_TAG, require("IKRigClient"))

	-- Bind metadata
	self._rigMetadata = {}
	self._maid:GiveTask(self._ikRigBinder:GetClassAddedSignal():Connect(function(class)
		self._rigMetadata[class] = 0
	end))
	self._maid:GiveTask(self._ikRigBinder:GetClassRemovingSignal():Connect(function(class)
		self._rigMetadata[class] = nil
	end))

	for _, class in pairs(self._ikRigBinder:GetAll()) do
		self._rigMetadata[class] = 0
	end

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_update()
	end))

	self._ikRigBinder:Init()
end

function IKServiceClient:GetRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	return self._ikRigBinder:Get(humanoid)
end

--- Exposed API for guns and other things to start setting aim position
--- which will override for a limited time
function IKServiceClient:SetAimPosition(position, optionalPriority)
	local aimer = self:GetLocalAimer()
	if not aimer then
		return
	end

	aimer:SetAimPosition(position, optionalPriority)
end

function IKServiceClient:GetLocalAimer()
	local rig = self:GetLocalPlayerRig()
	if not rig then
		return nil
	end

	return rig:GetLocalPlayerAimer()
end

function IKServiceClient:GetLocalPlayerRig()
	return IKRigUtils.getPlayerIKRig(self._ikRigBinder, Players.LocalPlayer)
end

function IKServiceClient:_update()
	debug.profilebegin("IKUpdate")

	local localAimer = self:GetLocalAimer()
	if localAimer then
		localAimer:UpdateStepped()
	end

	local camPosition = Workspace.CurrentCamera.CFrame.p

	for _, rig in pairs(self._ikRigBinder:GetAll()) do
		debug.profilebegin("RigUpdate")

		local position = rig:GetPositionOrNil()

		if position then
			local lastUpdateTime = self._rigMetadata[rig]
			local distance = (camPosition - position).Magnitude
			local timeBeforeNextUpdate = IKRigUtils.getTimeBeforeNextUpdate(distance)

			if (tick() - lastUpdateTime) >= timeBeforeNextUpdate then
				lastUpdateTime = tick()
				rig:Update() -- Update actual rig
			else
				rig:UpdateTransformOnly()
			end

			self._rigMetadata[rig] = lastUpdateTime
		end

		debug.profileend()
	end
	debug.profileend()
end


return IKServiceClient