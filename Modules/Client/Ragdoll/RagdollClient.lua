--- Client side ragdolling meant to be used with a binder
-- @classmod RagdollClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local RagdollBase = require("RagdollBase")
local CharacterUtils = require("CharacterUtils")
local HapticFeedbackUtils = require("HapticFeedbackUtils")

local RagdollClient = setmetatable({}, RagdollBase)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

function RagdollClient.new(humanoid)
	local self = setmetatable(RagdollBase.new(humanoid), RagdollClient)

	self:_setupState()

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		self:_setupCamera()
		self:_setupShake()
	end

	self:StopAnimations()

	return self
end

function RagdollClient:_setupShake()
	local lastInputType = UserInputService:GetLastInputType()
	if not HapticFeedbackUtils.setSmallVibration(lastInputType, 1) then
		return
	end

	local alive = true
	self._maid:GiveTask(function()
		alive = false
	end)

	spawn(function()
		for i=1, 0, -0.1 do
			HapticFeedbackUtils.setSmallVibration(lastInputType, i)
			wait(0.05)
		end
		HapticFeedbackUtils.setSmallVibration(lastInputType, 0)

		if alive then
			self._maid:GiveTask(function()
				HapticFeedbackUtils.smallVibrate(lastInputType)
			end)
		end
	end)
end

function RagdollClient:_setupState()
	self._obj.BreakJointsOnDeath = false

	self._obj:ChangeState(Enum.HumanoidStateType.Physics)
	self._maid:GiveTask(function()
		self._obj:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

function RagdollClient:_setupCamera()
	local model = self._obj.Parent
	if not model then
		return
	end

	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
	if not torso then
		warn("[RagdollClient] - No Torso")
		return
	end

	Workspace.CurrentCamera.CameraSubject = torso

	self._maid:GiveTask(function()
		Workspace.CurrentCamera.CameraSubject = self._obj
	end)
end

return RagdollClient