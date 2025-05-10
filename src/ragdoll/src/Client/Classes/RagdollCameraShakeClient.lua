--[=[
	@class RagdollCameraShakeClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local CameraStackService = require("CameraStackService")
local HapticFeedbackUtils = require("HapticFeedbackUtils")
local Maid = require("Maid")
local RagdollClient = require("RagdollClient")
local RagdollMotorUtils = require("RagdollMotorUtils")
local RagdollServiceClient = require("RagdollServiceClient")
local RxBrioUtils = require("RxBrioUtils")
local RxCharacterUtils = require("RxCharacterUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")

local RagdollCameraShakeClient = setmetatable({}, BaseObject)
RagdollCameraShakeClient.ClassName = "RagdollCameraShakeClient"
RagdollCameraShakeClient.__index = RagdollCameraShakeClient

function RagdollCameraShakeClient.new(humanoid: Humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollCameraShakeClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollServiceClient = self._serviceBag:GetService(RagdollServiceClient)
	self._cameraStackService = self._serviceBag:GetService(CameraStackService)
	self._ragdollBinder = self._serviceBag:GetService(RagdollClient)

	-- While we've got a charater and we're ragdolled
	self._maid:GiveTask(RxCharacterUtils.observeIsOfLocalCharacterBrio(self._obj)
		:Pipe({
			RxBrioUtils.switchMapBrio(function()
				return self._ragdollBinder:ObserveBrio(self._obj)
			end),
		})
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()

			maid:GiveTask(task.spawn(function()
				-- Yield in the same way just to ensure no weird shakes.
				RagdollMotorUtils.yieldUntilStepped()

				maid:GiveTask(self:_setupHapticFeedback())
				maid:GiveTask(self:_setupCameraShake(self._cameraStackService:GetImpulseCamera()))
			end))
		end))

	return self
end

function RagdollCameraShakeClient:_setupCameraShake(impulseCamera)
	local topMaid = Maid.new()

	-- TODO: Move out of this open source module

	-- Use the upper torso instead of the head because the upper torso shakes a lot less so
	-- we get a stronger response to full character movement.

	topMaid:GiveTask(RxInstanceUtils.observePropertyBrio(self._obj, "Parent", function(character)
		return character ~= nil
	end)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(character)
				return RxBrioUtils.flatCombineLatestBrio({
					upperTorso = RxR15Utils.observeCharacterPartBrio(character, "UpperTorso"),
					head = RxR15Utils.observeCharacterPartBrio(character, "Head"),
				}, function(state)
					return state.upperTorso and state.head
				end)
			end),
		})
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local state = brio:GetValue()

			local function getEstimatedVelocityFromUpperTorso()
				-- TODO: Consider neck attachments
				local headOffset = state.upperTorso.Size * Vector3.new(0, 0.5, 0)
					+ state.head.Size * Vector3.new(0, 0.5, 0)
				local headPosition = state.upperTorso.CFrame:PointToWorldSpace(headOffset)

				return state.upperTorso:GetVelocityAtPosition(headPosition)
			end

			local lastVelocity = getEstimatedVelocityFromUpperTorso()
			maid:GiveTask(RunService.Heartbeat:Connect(function()
				debug.profilebegin("ragdollcamerashake")

				local cameraCFrame = Workspace.CurrentCamera.CFrame

				local velocity = getEstimatedVelocityFromUpperTorso()
				local dVelocity = velocity - lastVelocity
				if dVelocity.magnitude >= 0 then
					if self._ragdollServiceClient:GetScreenShakeEnabled() then
						-- Defaults, but we should tune these
						local speed = 20
						local damper = 0.5

						speed = 40
						damper = 0.3

						impulseCamera:Impulse(
							cameraCFrame:vectorToObjectSpace(-0.1 * cameraCFrame.lookVector:Cross(dVelocity)),
							speed,
							damper
						)
					end
				end

				lastVelocity = velocity
				debug.profileend()
			end))
		end))

	return topMaid
end

function RagdollCameraShakeClient:_setupHapticFeedback()
	local maid = Maid.new()

	local lastInputType = UserInputService:GetLastInputType()
	if not HapticFeedbackUtils.setSmallVibration(lastInputType, 1) then
		return maid
	end

	maid:GiveTask(task.spawn(function()
		for i = 1, 0, -0.1 do
			HapticFeedbackUtils.setSmallVibration(lastInputType, i)
			task.wait(0.05)
		end

		HapticFeedbackUtils.setSmallVibration(lastInputType, 0)

		maid:GiveTask(function()
			HapticFeedbackUtils.smallVibrate(lastInputType)
		end)
	end))

	return maid
end

return Binder.new("RagdollCameraShake", RagdollCameraShakeClient)
