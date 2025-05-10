--[=[
	Torso resources for IK
	@class TorsoIKBase
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local IKResource = require("IKResource")
local IKResourceUtils = require("IKResourceUtils")
local Signal = require("Signal")
local TorsoIKUtils = require("TorsoIKUtils")

local TorsoIKBase = setmetatable({}, BaseObject)
TorsoIKBase.__index = TorsoIKBase
TorsoIKBase.ClassName = "TorsoIKBase"

function TorsoIKBase.new(humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(), TorsoIKBase)

	self._humanoid = humanoid or error("No humanoid")

	self.Pointed = self._maid:Add(Signal.new()) -- :Fire(position | nil)

	self._resources = IKResource.new(IKResourceUtils.createResource({
		name = "Character",
		robloxName = self._humanoid.Parent.Name,
		children = {
			IKResourceUtils.createResource({
				name = "RootPart",
				robloxName = "HumanoidRootPart",
			}),
			IKResourceUtils.createResource({
				name = "LowerTorso",
				robloxName = "LowerTorso",
			}),
			IKResourceUtils.createResource({
				name = "UpperTorso",
				robloxName = "UpperTorso",
				children = {
					IKResourceUtils.createResource({
						name = "Waist",
						robloxName = "Waist",
					}),
				},
			}),
			IKResourceUtils.createResource({
				name = "Head",
				robloxName = "Head",
				children = {
					IKResourceUtils.createResource({
						name = "Neck",
						robloxName = "Neck",
					}),
				},
			}),
		},
	}))
	self._maid:GiveTask(self._resources)
	self._resources:SetInstance(self._humanoid.Parent or error("No humanoid.Parent"))

	self._waistY = AccelTween.new(20)
	self._waistZ = AccelTween.new(15)

	self._headY = AccelTween.new(30)
	self._headZ = AccelTween.new(20)

	self._maid:GiveTask(self._resources.ReadyChanged:Connect(function()
		if self._resources:IsReady() then
			self:_recordLastValidTransforms()
			self:_updatePoint()
		end
	end))

	if self._resources:IsReady() then
		self:_recordLastValidTransforms()
	end

	return self
end

function TorsoIKBase:UpdateTransformOnly()
	if not self._relWaistTransform or not self._relNeckTransform then
		return
	end
	if not self._resources:IsReady() then
		return
	end

	local waist = self._resources:Get("Waist")
	local neck = self._resources:Get("Neck")

	-- Waist:
	local currentWaistTransform = waist.Transform
	if self._lastWaistTransform ~= currentWaistTransform then
		self._lastValidWaistTransform = currentWaistTransform
	end
	waist.Transform = self._lastValidWaistTransform * self._relWaistTransform
	self._lastWaistTransform = waist.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off

	-- Neck:
	local currentNeckTransform = neck.Transform
	if self._lastNeckTransform ~= currentNeckTransform then
		self._lastValidNeckTransform = currentNeckTransform
	end
	neck.Transform = self._lastValidNeckTransform * self._relNeckTransform
	self._lastNeckTransform = neck.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off
end

function TorsoIKBase:_recordLastValidTransforms()
	assert(self._resources:IsReady())
	local waist = self._resources:Get("Waist")
	local neck = self._resources:Get("Neck")

	self._lastValidWaistTransform = waist.Transform
	self._lastWaistTransform = waist.Transform

	self._lastValidNeckTransform = neck.Transform
	self._lastNeckTransform = neck.Transform
end

function TorsoIKBase:Update()
	self._relWaistTransform = CFrame.Angles(0, self._waistY.p, 0) * CFrame.Angles(self._waistZ.p, 0, 0)
	self._relNeckTransform = CFrame.Angles(0, self._headY.p, 0) * CFrame.Angles(self._headZ.p, 0, 0)

	self:UpdateTransformOnly()
end

function TorsoIKBase:GetAimPosition()
	return self._target -- May return nil
end

function TorsoIKBase:Point(position)
	self._target = position

	if self._resources:IsReady() then
		self:_updatePoint()
	end

	self.Pointed:Fire(self._target)
end

function TorsoIKBase:_updatePoint()
	assert(self._resources:IsReady())

	if self._target then
		local rootPart = self._resources:Get("RootPart")
		local waistY, headY, waistZ, headZ = TorsoIKUtils.getTargetAngles(rootPart, self._target)

		self._waistY.t = waistY
		self._headY.t = headY
		self._waistZ.t = waistZ
		self._headZ.t = headZ
	else
		self._waistY.t = 0
		self._headY.t = 0
		self._waistZ.t = 0
		self._headZ.t = 0
	end
end

--[=[
	Helper method used for other IK
	@return CFrame?
]=]
function TorsoIKBase:GetTargetUpperTorsoCFrame()
	if not self._resources:IsReady() then
		return nil
	end

	local waist = self._resources:Get("Waist")
	local lowerTorso = self._resources:Get("LowerTorso")

	local estimated_transform = self._lastValidWaistTransform
		* CFrame.Angles(0, self._waistY.t, 0)
		* CFrame.Angles(self._waistZ.t, 0, 0)

	return lowerTorso.CFrame * waist.C0 * estimated_transform * waist.C1:inverse()
end

function TorsoIKBase:GetUpperTorsoCFrame()
	if not self._resources:IsReady() then
		return nil
	end

	local lowerTorso = self._resources:Get("LowerTorso")

	return lowerTorso.CFrame
end

return TorsoIKBase
