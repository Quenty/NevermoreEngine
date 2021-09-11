--- Handles IK for local client
-- @classmod IKServiceClient

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local CameraStackService = require("CameraStackService")
local IKBindersClient = require("IKBindersClient")
local IKRigUtils = require("IKRigUtils")
local Maid = require("Maid")

local IKServiceClient = {}

function IKServiceClient:Init(serviceBag)
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._lookAround = true

	self._ikBinders = serviceBag:GetService(IKBindersClient)
	serviceBag:GetService(CameraStackService)
end

function IKServiceClient:Start()
	assert(self._maid, "Not initialized")

	self._maid:GiveTask(RunService.Stepped:Connect(function()
		self:_updateStepped()
	end))
end

function IKServiceClient:GetRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._ikBinders.IKRig:Get(humanoid)
end

function IKServiceClient:PromiseRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	return self._ikBinders.IKRig:Promise(humanoid)
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

function IKServiceClient:SetLookAround(lookAround)
	self._lookAround = lookAround
end

function IKServiceClient:GetLocalAimer()
	local rig = self:GetLocalPlayerRig()
	if not rig then
		return nil
	end

	return rig:GetLocalPlayerAimer()
end

function IKServiceClient:GetLocalPlayerRig()
	assert(self._ikBinders.IKRig, "Not initialize")

	return IKRigUtils.getPlayerIKRig(self._ikBinders.IKRig, Players.LocalPlayer)
end

function IKServiceClient:_updateStepped()
	debug.profilebegin("IKUpdate")

	local localAimer = self:GetLocalAimer()
	if localAimer then
		localAimer:SetLookAround(self._lookAround)
		localAimer:UpdateStepped()
	end

	local camPosition = Workspace.CurrentCamera.CFrame.p

	for _, rig in pairs(self._ikBinders.IKRig:GetAll()) do
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