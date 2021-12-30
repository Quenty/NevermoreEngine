--[=[
	Client side ragdolling meant to be used with a binder
	@class RagdollClient
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local CameraStackService = require("CameraStackService")
local CharacterUtils = require("CharacterUtils")
local HapticFeedbackUtils = require("HapticFeedbackUtils")

local RagdollClient = setmetatable({}, BaseObject)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

function RagdollClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollClient)

	self._cameraStackService = serviceBag:GetService(CameraStackService)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		self:_setupHapticFeedback()
		self:_setupCameraShake(self._cameraStackService:GetImpulseCamera())
	end

	return self
end

-- TODO: Move out of this open source module
function RagdollClient:_setupCameraShake(impulseCamera)
	local head = self._obj.Parent:FindFirstChild("Head")
	if not head then
		return
	end

	local lastVelocity = head.Velocity
	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		local cameraCFrame = Workspace.CurrentCamera.CFrame

		local velocity = head.Velocity
		local dVelocity = velocity - lastVelocity
		if dVelocity.magnitude >= 0 then
			impulseCamera:Impulse(cameraCFrame:vectorToObjectSpace(-0.1*cameraCFrame.lookVector:Cross(dVelocity)))
		end

		lastVelocity = velocity
	end))
end

function RagdollClient:_setupHapticFeedback()
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
			task.wait(0.05)
		end
		HapticFeedbackUtils.setSmallVibration(lastInputType, 0)

		if alive then
			self._maid:GiveTask(function()
				HapticFeedbackUtils.smallVibrate(lastInputType)
			end)
		end
	end)
end

return RagdollClient