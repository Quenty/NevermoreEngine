---
-- @classmod IKRigBase
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local TorsoIKBase = require("TorsoIKBase")
local Promise = require("Promise")
local promiseChild = require("promiseChild")
local PromiseUtils = require("PromiseUtils")
local CharacterUtil = require("CharacterUtil")
local Signal = require("Signal")
local ArmIKBase = require("ArmIKBase")
local ArmFABRIKBase = require("ArmFABRIKBase")

local IKRigBase = setmetatable({}, BaseObject)
IKRigBase.ClassName = "IKRigBase"
IKRigBase.__index = IKRigBase

function IKRigBase.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), IKRigBase)

	self.Updated = Signal.new()
	self._maid:GiveTask(self.Updated)

	self._ikTargets = {}
	self._character = humanoid.Parent or error("No character")

	self._lastUpdateTime = 0

	return self
end

function IKRigBase:GetLastUpdateTime()
	return self._lastUpdateTime
end

function IKRigBase:GetPlayer()
	return CharacterUtil.GetPlayerFromCharacter(self._obj)
end

function IKRigBase:GetHumanoid()
	return self._obj
end

function IKRigBase:Update()
	self._lastUpdateTime = tick()
	self.Updated:Fire()

	for _, item in pairs(self._ikTargets) do
		item:Update()
	end
end

function IKRigBase:UpdateTransformOnly()
	for _, item in pairs(self._ikTargets) do
		item:UpdateTransformOnly()
	end
end

function IKRigBase:PromiseTorso()
	if self._torsoPromise then
		return Promise.resolved(self._torsoPromise)
	end

	self._torsoPromise = self:_promiseNewTorso()
	return Promise.resolved(self._torsoPromise)
end

function IKRigBase:GetTorso()
	if not self._torsoPromise then
		self:PromiseTorso()
	end

	if self._torsoPromise:IsFulfilled() then
		return self._torsoPromise:Wait()
	else
		return nil
	end
end

function IKRigBase:PromiseLeftArm()
	if self._leftArm then
		return Promise.resolved(self._leftArm)
	end
	self._leftArm = self:_getNewArm("Left")
	return Promise.resolved(self._leftArm)
end

function IKRigBase:GetLeftArm()
	if self._leftArmPromise:IsFulfilled() then
		return self._leftArmPromise:Wait()
	else
		return nil
	end
end

function IKRigBase:PromiseRightArm()
	if self._rightArm then
		return Promise.resolved(self._rightArm)
	end
	self._rightArm = self:_getNewArm("Right")
	return Promise.resolved(self._rightArm)
end

function IKRigBase:GetRightArm()
	if self._rightArmPromise:IsFulfilled() then
		return self._rightArmPromise:Wait()
	else
		return nil
	end
end

function IKRigBase:_getNewArm(armName)
	assert(armName == "Left" or armName == "Right")

	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	local newIk = ArmIKBase.new(self._obj, armName)
	table.insert(self._ikTargets, newIk)

	return newIk
end

function IKRigBase:_promiseNewTorso()
	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	return self._maid:GivePromise(PromiseUtils.all({
			promiseChild(self._character, "HumanoidRootPart");
			promiseChild(self._character, "LowerTorso");
			promiseChild(self._character, "UpperTorso");
			promiseChild(self._character, "Head");
		}))
		:Then(function(rootPart, lowerTorso, upperTorso, head)
			if not lowerTorso:IsA("BasePart") then
				return Promise.rejected("LowerTorso is not a BasePart")
			end
			if not upperTorso:IsA("BasePart") then
				return Promise.rejected("UpperTorso is not a BasePart")
			end
			if not head:IsA("BasePart") then
				return Promise.rejected("Head is not a BasePart")
			end

			return self._maid:GivePromise(PromiseUtils.all({
				Promise.resolved(rootPart);
				Promise.resolved(lowerTorso);
				Promise.resolved(upperTorso);
				promiseChild(upperTorso, "Waist");
				promiseChild(head, "Neck");
			}))
		end)
		:Then(function(rootPart, lowerTorso, upperTorso, waist, neck)
			local newIk = TorsoIKBase.new(rootPart, lowerTorso, upperTorso, waist, neck)
			self._maid:GiveTask(newIk)

			table.insert(self._ikTargets, 1, newIk)

			return newIk
		end)
end

return IKRigBase