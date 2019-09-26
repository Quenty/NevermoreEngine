--- Handles IK rigging for a humanoid
-- @classmod IKRigClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local ArmIK = require("ArmIK")
local IKRigBase = require("IKRigBase")
local IKConstants = require("IKConstants")
local IKRigAimerLocalPlayer = require("IKRigAimerLocalPlayer")
local Promise = require("Promise")
local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local Signal = require("Signal")

local IKRigClient = setmetatable({}, IKRigBase)
IKRigClient.ClassName = "IKRigClient"
IKRigClient.__index = IKRigClient

require("PromiseRemoteEventMixin"):Add(IKRigClient, IKConstants.REMOTE_EVENT_NAME)

function IKRigClient.new(humanoid)
	local self = setmetatable(IKRigBase.new(humanoid), IKRigClient)

	self.Updated = Signal.new()
	self._maid:GiveTask(self.Updated)

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

function IKRigClient:PromiseLeftArm()
	if self._leftArmPromise then
		return Promise.resolved(self._leftArmPromise)
	end
	self._leftArmPromise = self:_promiseNewArm("Left")
	return Promise.resolved(self._leftArmPromise)
end

function IKRigClient:GetLeftArm()
	if self._leftArmPromise:IsFulfilled() then
		return self._leftArmPromise:Wait()
	else
		return nil
	end
end

function IKRigClient:PromiseRightArm()
	if self._rightArmPromise then
		return Promise.resolved(self._rightArmPromise)
	end
	self._rightArmPromise = self:_promiseNewArm("Right")
	return Promise.resolved(self._rightArmPromise)
end

function IKRigClient:GetRightArm()
	if self._rightArmPromise:IsFulfilled() then
		return self._rightArmPromise:Wait()
	else
		return nil
	end
end

function IKRigClient:GetLocalPlayerAimer()
	return self._aimer
end

function IKRigClient:_handleRemoteEventClient(newTarget)
	assert(typeof(newTarget) == "Vector3")

	local torso = self:GetTorso()

	if torso then
		torso:Point(newTarget)
	end
end

function IKRigClient:_setupLocalPlayer(remoteEvent)
	self._aimer = IKRigAimerLocalPlayer.new(self, remoteEvent)
	self._maid:GiveTask(self._aimer)
end

function IKRigClient:_promiseNewArm(armName)
	assert(armName == "Left" or armName == "Right")

	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	return self._maid:GivePromise(PromiseUtils.all({
			promiseChild(self._character, armName .. "Hand");
			promiseChild(self._character, armName .. "UpperArm");
			promiseChild(self._character, armName .. "LowerArm");
		}))
		:Then(function(hand, upperArm, lowerArm)
			return self._maid:GivePromise(PromiseUtils.all({
				promiseChild(hand, armName .. "GripAttachment");
				promiseChild(upperArm, armName .. "Shoulder");
				promiseChild(lowerArm, armName .. "Elbow");
				promiseChild(hand, armName .. "Wrist");
			}))
		end)
		:Then(function(gripAttachment, shoulder, elbow, wrist)
			local newIk = ArmIK.new(gripAttachment, shoulder, elbow, wrist)
			self._maid:GiveTask(newIk)

			table.insert(self._ikTargets, newIk)

			return newIk
		end)
end


return IKRigClient