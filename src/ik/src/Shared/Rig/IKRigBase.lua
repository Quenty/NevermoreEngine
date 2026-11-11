--!strict
--[=[
	@class IKRigBase
]=]

local require = require(script.Parent.loader).load(script)

local ArmIKBase = require("ArmIKBase")
local BaseObject = require("BaseObject")
local CharacterUtils = require("CharacterUtils")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TorsoIKBase = require("TorsoIKBase")

local IKRigBase = setmetatable({}, BaseObject)
IKRigBase.ClassName = "IKRigBase"
IKRigBase.__index = IKRigBase

export type IKRigBase =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			Updating: Signal.Signal<()>,
			_ikTargets: { any },
			_character: Instance,
			_lastUpdateTime: number,
			_torso: TorsoIKBase.TorsoIKBase?,
			_leftArm: ArmIKBase.ArmIKBase?,
			_rightArm: ArmIKBase.ArmIKBase?,
		},
		{} :: typeof({ __index = IKRigBase })
	))
	& BaseObject.BaseObject

function IKRigBase.new(humanoid: Humanoid, serviceBag: ServiceBag.ServiceBag): IKRigBase
	local self: IKRigBase = setmetatable(BaseObject.new(humanoid) :: any, IKRigBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.Updating = self._maid:Add(Signal.new())

	self._ikTargets = {}
	self._character = humanoid.Parent or error("No character")

	self._lastUpdateTime = 0

	return self
end

function IKRigBase.GetLastUpdateTime(self: IKRigBase): number
	return self._lastUpdateTime
end

function IKRigBase.GetPlayer(self: IKRigBase): Player?
	return CharacterUtils.getPlayerFromCharacter(self:GetHumanoid())
end

function IKRigBase.GetHumanoid(self: IKRigBase): Humanoid
	return self._obj :: Humanoid
end

function IKRigBase.Update(self: IKRigBase): ()
	self._lastUpdateTime = tick()
	self.Updating:Fire()

	for _, item in self._ikTargets do
		item:Update()
	end
end

function IKRigBase.UpdateTransformOnly(self: IKRigBase): ()
	for _, item in self._ikTargets do
		item:UpdateTransformOnly()
	end
end

function IKRigBase.PromiseTorso(self: IKRigBase): Promise.Promise<TorsoIKBase.TorsoIKBase?>
	return Promise.resolved(self:GetTorso())
end

function IKRigBase.GetTorso(self: IKRigBase): TorsoIKBase.TorsoIKBase?
	if not self._torso then
		self._torso = self:_getNewTorso()
	end

	return self._torso
end

function IKRigBase.PromiseLeftArm(self: IKRigBase): Promise.Promise<ArmIKBase.ArmIKBase?>
	if self:GetHumanoid().RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	return Promise.resolved(self:GetLeftArm())
end

function IKRigBase.GetLeftArm(self: IKRigBase): ArmIKBase.ArmIKBase?
	if not self._leftArm then
		self._leftArm = self:_getNewArm("Left")
	end

	return self._leftArm
end

function IKRigBase.PromiseRightArm(self: IKRigBase): Promise.Promise<ArmIKBase.ArmIKBase?>
	if self:GetHumanoid().RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.rejected("Rig is not HumanoidRigType.R15")
	end

	return Promise.resolved(self:GetRightArm())
end

function IKRigBase.GetRightArm(self: IKRigBase): ArmIKBase.ArmIKBase?
	if not self._rightArm then
		self._rightArm = self:_getNewArm("Right")
	end

	return self._rightArm
end

function IKRigBase._getNewArm(self: IKRigBase, armName: string): ArmIKBase.ArmIKBase?
	assert(armName == "Left" or armName == "Right", "Bad armName")

	if self:GetHumanoid().RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end

	local newIk = ArmIKBase.new(self:GetHumanoid(), armName, self._serviceBag)
	table.insert(self._ikTargets, newIk)

	return newIk
end

function IKRigBase._getNewTorso(self: IKRigBase): TorsoIKBase.TorsoIKBase?
	if self:GetHumanoid().RigType ~= Enum.HumanoidRigType.R15 then
		warn("Rig is not HumanoidRigType.R15")
		return nil
	end

	local newIk = TorsoIKBase.new(self:GetHumanoid())
	self._maid:GiveTask(newIk)

	table.insert(self._ikTargets, 1, newIk)

	return newIk
end

return IKRigBase
