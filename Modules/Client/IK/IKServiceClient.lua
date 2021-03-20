--- Handles IK for local client
-- @classmod IKServiceClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Binder = require("Binder")
local IKConstants = require("IKConstants")
local IKRigUtils = require("IKRigUtils")
local Maid = require("Maid")
local promiseBoundClass = require("promiseBoundClass")

local IKServiceClient = {}

function IKServiceClient:Init()
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._ikRigBinder = Binder.new(IKConstants.COLLECTION_SERVICE_TAG, require("IKRigClient"))
	self._noDefaultIK = false
end

function IKServiceClient:Start()
	assert(self._maid, "Not initialized")

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_updateStepped()
	end))

	self._ikRigBinder:Start()
end

function IKServiceClient:PromiseRig(maid, humanoid)
	assert(maid)
	assert(typeof(humanoid) == "Instance")

	local promise = promiseBoundClass(self._ikRigBinder, humanoid)
	maid:GiveTask(promise)
	return promise
end

function IKServiceClient:GetRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	return self._ikRigBinder:Get(humanoid)
end

--- Exposed API for guns and other things to start setting aim position
--- which will override for a limited time.
-- @param position May be nil to set no position
function IKServiceClient:SetAimPosition(position, optionalPriority)
	local aimer = self:GetLocalAimer()
	if not aimer then
		return
	end

	aimer:SetAimPosition(position, optionalPriority)
end

function IKServiceClient:SetNoDefaultIK(noDefaultIK)
	self._noDefaultIK = noDefaultIK
end

function IKServiceClient:GetLocalAimer()
	local rig = self:GetLocalPlayerRig()
	if not rig then
		return nil
	end

	return rig:GetLocalPlayerAimer()
end

function IKServiceClient:GetLocalPlayerRig()
	assert(self._ikRigBinder, "Not initialize")

	return IKRigUtils.getPlayerIKRig(self._ikRigBinder, Players.LocalPlayer)
end

function IKServiceClient:_updateStepped()
	debug.profilebegin("IKUpdate")

	local localAimer = self:GetLocalAimer()
	if localAimer then
		localAimer:SetNoDefaultIK(self._noDefaultIK)
		localAimer:UpdateStepped()
	end

	local camPosition = Workspace.CurrentCamera.CFrame.p

	for _, rig in pairs(self._ikRigBinder:GetAll()) do
		debug.profilebegin("RigUpdate")

		local position = rig:GetPositionOrNil()

		if position then
			local lastUpdateTime = rig:GetLastUpdateTime()
			local distance = (camPosition - position).Magnitude
			local timeBeforeNextUpdate = IKRigUtils.getTimeBeforeNextUpdate(distance)

			if (tick() - lastUpdateTime) >= timeBeforeNextUpdate then
				rig:Update() -- Update actual rig
			else
				rig:UpdateTransformOnly()
			end
		end

		debug.profileend()
	end
	debug.profileend()
end


return IKServiceClient