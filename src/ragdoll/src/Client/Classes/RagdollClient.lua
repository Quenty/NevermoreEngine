--[=[
	Client side ragdolling meant to be used with a binder. See [RagdollBindersClient].
	While a humanoid is bound with this class, it is ragdolled.

	@client
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
local RagdollServiceClient = require("RagdollServiceClient")
local RagdollMotorUtils = require("RagdollMotorUtils")
local RxR15Utils = require("RxR15Utils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local RagdollClient = setmetatable({}, BaseObject)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

--[=[
	Constructs a new RagdollClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollClient
]=]
function RagdollClient.new(humanoid, serviceBag)
	local self = setmetatable(BaseObject.new(humanoid), RagdollClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._ragdollServiceClient = self._serviceBag:GetService(RagdollServiceClient)
	self._cameraStackService = self._serviceBag:GetService(CameraStackService)

	local player = CharacterUtils.getPlayerFromCharacter(self._obj)
	if player == Players.LocalPlayer then
		self._maid:GiveTask(task.spawn(function()
			-- Yield in the same way just to ensure no weird shakes.
			RagdollMotorUtils.yieldUntilStepped()

			self:_setupHapticFeedback()
			self:_setupCameraShake(self._cameraStackService:GetImpulseCamera())
		end))
	end

	return self
end

function RagdollClient:_setupCameraShake(impulseCamera)
	-- TODO: Move out of this open source module

	-- Use the upper torso instead of the head because the upper torso shakes a lot less so
	-- we get a stronger response to full character movement.

	self._maid:GiveTask(RxInstanceUtils.observePropertyBrio(self._obj, "Parent", function(character)
		return character ~= nil
	end):Pipe({
		RxBrioUtils.switchMapBrio(function(character)
			return RxBrioUtils.flatCombineLatestBrio({
				upperTorso = RxR15Utils.observeCharacterPartBrio(character, "UpperTorso");
				head = RxR15Utils.observeCharacterPartBrio(character, "Head")
			}, function(state)
				return state.upperTorso and state.head
			end)
		end);
	}):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local state = brio:GetValue()

		local function getEstimatedVelocityFromUpperTorso()
			-- TODO: Consider neck attachments
			local headOffset = state.upperTorso.Size*Vector3.new(0, 0.5, 0)
				+ state.head.Size*Vector3.new(0, 0.5, 0)
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
					impulseCamera:Impulse(cameraCFrame:vectorToObjectSpace(-0.1*cameraCFrame.lookVector:Cross(dVelocity)))
				end
			end

			lastVelocity = velocity
			debug.profileend()
		end))
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

	task.spawn(function()
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