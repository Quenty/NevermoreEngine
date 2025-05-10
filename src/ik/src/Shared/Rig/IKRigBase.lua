--[=[
	@class IKRigBase
]=]

local require = require(script.Parent.loader).load(script)

local ArmIKBase = require("ArmIKBase")
local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local Promise = require("Promise")
local Signal = require("Signal")
local TorsoIKBase = require("TorsoIKBase")

local IKRigBase = setmetatable({}, BaseObject)
IKRigBase.ClassName = "IKRigBase"
IKRigBase.__index = IKRigBase

function IKRigBase.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid, serviceBag), IKRigBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.Updating = self._maid:Add(Signal.new())

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

	for _, item in self._ikTargets do
		item:Update()
	end
end

function IKRigBase:UpdateTransformOnly()
	for _, item in self._ikTargets do
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
	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	return Promise.resolved(self:GetLeftArm())
end

function IKRigBase:GetLeftArm()
	if not self._leftArm then
		self._leftArm = self:_getNewArm("Left")
	end

	return self._leftArm
end

function IKRigBase:PromiseRightArm()
	if self._obj.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

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
		return nil
	end

	local newIk = ArmIKBase.new(self._obj, armName, self._serviceBag)
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
