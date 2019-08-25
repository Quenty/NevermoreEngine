--- Base class for ragdolls, meant to be used with binders
-- @classmod Ragdoll

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RagdollBase = require("RagdollBase")
local RagdollUtils = require("RagdollUtils")

local Ragdoll = setmetatable({}, RagdollBase)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

function Ragdoll.new(humanoid)
	local self = setmetatable(RagdollBase.new(humanoid), Ragdoll)

	self._obj.BreakJointsOnDeath = false
	self._obj:ChangeState(Enum.HumanoidStateType.Physics)
	self:StopAnimations()

	self._maid:GiveTask(function()
		self._obj:ChangeState(Enum.HumanoidStateType.Running)
	end)

	self:_setupRootPart()

	for _, balljoint in pairs(RagdollUtils.createBallJoints(self._obj)) do
		self._maid:GiveTask(balljoint)
	end

	for _, noCollision in pairs(RagdollUtils.createNoCollision(self._obj)) do
		self._maid:GiveTask(noCollision)
	end

	for _, motor in pairs(RagdollUtils.getMotors(self._obj)) do
		local originalParent = motor.Parent
		motor.Parent = nil

		self._maid:GiveTask(function()
			if originalParent:IsDescendantOf(workspace) then
				motor.Parent = originalParent
			else
				motor:Destroy()
			end
		end)
	end

	return self
end

function Ragdoll:_setupRootPart()
	local rootPart = self._obj.RootPart
	if not rootPart then
		return
	end

	rootPart.Massless = true
	rootPart.CanCollide = false

	self._maid:GiveTask(function()
		rootPart.Massless = false
		rootPart.CanCollide = true
	end)
end

return Ragdoll