---
-- @classmod IKRigBase
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TorsoIKBase = require("TorsoIKBase")
local Promise = require("Promise")
local CharacterUtils = require("CharacterUtils")
local Signal = require("Signal")
local ArmIKBase = require("ArmIKBase")

local IKRigBase = setmetatable({}, BaseObject)
IKRigBase.ClassName = "IKRigBase"
IKRigBase.__index = IKRigBase

function IKRigBase.new(humanoid)
	local self = setmetatable(BaseObject.new(humanoid), IKRigBase)

	self.Updating = Signal.new()
	self._maid:GiveTask(self.Updating)

	self._ikTargets = {}
	self._character = humanoid.Parent or error("No character")

	self._lastUpdateTime = 0

	return self
end

function IKRigBase:GetLastUpdateTime()
	return self._lastUpdateTime
end

function IKRigBase:GetPlayer()
	return CharacterUtils.getPlayerFromCharacter(self._obj)
end

function IKRigBase:GetHumanoid()
	return self._obj
end

function IKRigBase:Update()
	self._lastUpdateTime = tick()
	self.Updating:Fire()

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
	return Promise.resolved(self:GetTorso())
end

function IKRigBase:GetTorso()
	if not self._torso then
		self._torso = self:_getNewTorso()
	end

	return self._torso
end

function IKRigBase:PromiseLeftArm()
	return Promise.resolved(self:GetLeftArm())
end

function IKRigBase:GetLeftArm()
	if not self._leftArm then
		self._leftArm = self:_getNewArm("Left")
	end

	return self._leftArm
end

function IKRigBase:PromiseRightArm()
	return Promise.resolved(self:GetRightArm())
end

function IKRigBase:GetRightArm()
	if not self._rightArm then
		self._rightArm = self:_getNewArm("Right")
	end

	return self._rightArm
end

function IKRigBase:_getNewArm(armName)
	assert(armName == "Left" or armName == "Right", "Bad armName")

	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	local newIk = ArmIKBase.new(self._obj, armName)
	table.insert(self._ikTargets, newIk)

	return newIk
end

function IKRigBase:_getNewTorso()
	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		warn("Rig is not HumanoidRigType.R15")
		return nil
	end

	local newIk = TorsoIKBase.new(self._obj)
	self._maid:GiveTask(newIk)

	table.insert(self._ikTargets, 1, newIk)

	return newIk
end

return IKRigBase