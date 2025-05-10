--[=[
	Provides IK for a given arm
	@class ArmIKBase
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local ArmIKUtils = require("ArmIKUtils")
local BaseObject = require("BaseObject")
local IKAimPositionPriorites = require("IKAimPositionPriorites")
local LimbIKUtils = require("optional")(require, "LimbIKUtils")
local Maid = require("Maid")
local Math = require("Math")
local Motor6DSmoothTransformer = require("Motor6DSmoothTransformer")
local Motor6DStackInterface = require("Motor6DStackInterface")
local QFrame = require("QFrame")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local ValueObject = require("ValueObject")

local CFA_90X = CFrame.Angles(math.pi / 2, 0, 0)
local USE_OLD_IK_SYSTEM = (not LimbIKUtils) or false
local USE_MOTOR_6D_RAW = false

local ArmIKBase = setmetatable({}, BaseObject)
ArmIKBase.ClassName = "ArmIKBase"
ArmIKBase.__index = ArmIKBase

function ArmIKBase.new(humanoid: Humanoid, armName, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(), ArmIKBase)

	self._humanoid = humanoid or error("No humanoid")
	self._armName = assert(armName, "No armName")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._grips = {}

	if self._armName == "Left" then
		self._direction = 1
	elseif self._armName == "Right" then
		self._direction = -1
	else
		error(string.format("[ArmIKBase] - Bad armName %q", tostring(armName)))
	end

	self._gripping = self._maid:Add(ValueObject.new(false, "boolean"))

	self._maid:GiveTask(self:_observeCharacterBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local character = brio:GetValue()

		maid:GiveTask(self._gripping:Observe():Subscribe(function(isGripping)
			if isGripping then
				maid._gripping = self:_startUpdateLoop(character)
			else
				maid._gripping = nil
			end
		end))
	end))

	self._maid:GiveTask(self:_observeStateBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local state = brio:GetValue()
		local maid = brio:ToMaid()

		self._lastState = state

		maid:GiveTask(function()
			if self._lastState == state then
				self._lastState = nil
			end
		end)
	end))

	return self
end

function ArmIKBase:_startUpdateLoop(character)
	local maid = Maid.new()

	maid:GiveTask(ArmIKUtils.ensureMotorAnimated(character, self._armName))

	maid:GiveTask(self:_ensureAnimator(character, self._armName .. "UpperArm", self._armName .. "Shoulder", function()
		return self._shoulderTransform
	end))
	maid:GiveTask(self:_ensureAnimator(character, self._armName .. "LowerArm", self._armName .. "Elbow", function()
		return self._elbowTransform
	end))
	maid:GiveTask(self:_ensureAnimator(character, self._armName .. "Hand", self._armName .. "Wrist", function()
		return self._wristTransform
	end))

	return maid
end

function ArmIKBase:_ensureAnimator(character, partName, motorName, getTranform)
	local topMaid = Maid.new()

	topMaid:GiveTask(RxR15Utils.observeRigMotorBrio(character, partName, motorName)
		:Pipe({
			RxBrioUtils.switchMapBrio(function(motor)
				return Motor6DStackInterface:ObserveLastImplementationBrio(motor, self._tieRealmService:GetTieRealm())
			end),
		})
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, motor6DStack = brio:ToMaidAndValue()

			local transformer = Motor6DSmoothTransformer.new(getTranform)
			transformer:SetTarget(1)

			local cleanup = motor6DStack:Push(transformer)

			maid:GiveTask(function()
				transformer:SetTarget(0)

				task.delay(2, function()
					transformer:Destroy()
					cleanup()
				end)
			end)
		end))

	return topMaid
end

function ArmIKBase:_observeCharacterBrio()
	if self._characterObservable then
		return self._characterObservable
	end

	self._characterObservable = RxInstanceUtils.observePropertyBrio(self._humanoid, "Parent", function(parent)
		return parent ~= nil
	end):Pipe({
		Rx.shareReplay(1),
	})

	return self._characterObservable
end

function ArmIKBase:_observeStateBrio()
	return self:_observeCharacterBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(character)
			local observeUpperTorsoBrio = RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", "UpperTorso")
				:Pipe({
					Rx.shareReplay(1),
				})
			local observeUpperArmBrio =
				RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", self._armName .. "UpperArm"):Pipe({
					Rx.shareReplay(1),
				})
			local observeLowerArmBrio =
				RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", self._armName .. "LowerArm"):Pipe({
					Rx.shareReplay(1),
				})
			local observeHandBrio =
				RxInstanceUtils.observeLastNamedChildBrio(character, "BasePart", self._armName .. "Hand"):Pipe({
					Rx.shareReplay(1),
				})

			local observeShoulderBrio = observeUpperArmBrio:Pipe({
				RxBrioUtils.switchMapBrio(function(upperArm)
					return RxInstanceUtils.observeLastNamedChildBrio(upperArm, "Motor6D", self._armName .. "Shoulder")
				end),
				Rx.shareReplay(1),
			})
			local observeElbowBrio = observeLowerArmBrio:Pipe({
				RxBrioUtils.switchMapBrio(function(lowerArm)
					return RxInstanceUtils.observeLastNamedChildBrio(lowerArm, "Motor6D", self._armName .. "Elbow")
				end),
				Rx.shareReplay(1),
			})
			local observeWristBrio = observeHandBrio:Pipe({
				RxBrioUtils.switchMapBrio(function(hand)
					return RxInstanceUtils.observeLastNamedChildBrio(hand, "Motor6D", self._armName .. "Wrist")
				end),
				Rx.shareReplay(1),
			})

			return RxBrioUtils.flatCombineLatest({
				UpperTorso = observeUpperTorsoBrio,
				UpperArm = observeUpperArmBrio,
				LowerArm = observeLowerArmBrio,
				Hand = observeHandBrio,

				Shoulder = observeShoulderBrio,
				Elbow = observeElbowBrio,
				Wrist = observeWristBrio,

				ShoulderMotor6DStack = observeShoulderBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(motor)
						return Motor6DStackInterface:ObserveLastImplementationBrio(
							motor,
							self._tieRealmService:GetTieRealm()
						)
					end),
					Rx.defaultsToNil,
				}),
				ElbowMotor6DStack = observeElbowBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(motor)
						return Motor6DStackInterface:ObserveLastImplementationBrio(
							motor,
							self._tieRealmService:GetTieRealm()
						)
					end),
					Rx.defaultsToNil,
				}),
				WristMotor6DStack = observeWristBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(motor)
						return Motor6DStackInterface:ObserveLastImplementationBrio(
							motor,
							self._tieRealmService:GetTieRealm()
						)
					end),
					Rx.defaultsToNil,
				}),

				UpperTorsoShoulderRigAttachment = observeUpperTorsoBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(upperTorso)
						return RxInstanceUtils.observeLastNamedChildBrio(
							upperTorso,
							"Attachment",
							self._armName .. "ShoulderRigAttachment"
						)
					end),
				}),
				UpperArmShoulderRigAttachment = observeUpperArmBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(upperArm)
						return RxInstanceUtils.observeLastNamedChildBrio(
							upperArm,
							"Attachment",
							self._armName .. "ShoulderRigAttachment"
						)
					end),
				}),
				UpperArmElbowRigAttachment = observeUpperArmBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(upperArm)
						return RxInstanceUtils.observeLastNamedChildBrio(
							upperArm,
							"Attachment",
							self._armName .. "ElbowRigAttachment"
						)
					end),
				}),
				LowerArmElbowRigAttachment = observeLowerArmBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(lowerArm)
						return RxInstanceUtils.observeLastNamedChildBrio(
							lowerArm,
							"Attachment",
							self._armName .. "ElbowRigAttachment"
						)
					end),
				}),
				LowerArmWristRigAttachment = observeLowerArmBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(lowerArm)
						return RxInstanceUtils.observeLastNamedChildBrio(
							lowerArm,
							"Attachment",
							self._armName .. "WristRigAttachment"
						)
					end),
				}),
				HandWristRigAttachment = observeHandBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(hand)
						return RxInstanceUtils.observeLastNamedChildBrio(
							hand,
							"Attachment",
							self._armName .. "WristRigAttachment"
						)
					end),
				}),
				HandGripAttachment = observeHandBrio:Pipe({
					RxBrioUtils.switchMapBrio(function(hand)
						return RxInstanceUtils.observeLastNamedChildBrio(
							hand,
							"Attachment",
							self._armName .. "GripAttachment"
						)
					end),
				}),
			})
		end),
		Rx.throttleDefer(),
	})
end

function ArmIKBase:Grip(attachment, priority)
	assert(typeof(attachment) == "Instance", "Bad attachment")
	assert(type(priority) == "number" or priority == nil, "Bad priority")

	priority = priority or IKAimPositionPriorites.DEFAULT

	local gripData = {
		attachment = attachment,
		priority = priority,
	}

	local i = 1
	while self._grips[i] and self._grips[i].priority > priority do
		i = i + 1
	end

	table.insert(self._grips, i, gripData)
	self._gripping.Value = true

	return function()
		if self.Destroy then
			self:_stopGrip(gripData)
		end
	end
end

function ArmIKBase:_stopGrip(grip)
	for index, value in self._grips do
		if value == grip then
			table.remove(self._grips, index)
			break
		end
	end

	if not next(self._grips) then
		self._gripping.Value = false
	end
end

-- Sets transform
if RunService:IsRunning() and not USE_MOTOR_6D_RAW then
	function ArmIKBase:UpdateTransformOnly()
		-- no work!
	end
else
	function ArmIKBase:UpdateTransformOnly()
		if not self._grips[1] then
			return
		end
		if not (self._shoulderTransform and self._elbowTransform and self._wristTransform) then
			return
		end
		if not self._lastState then
			return
		end

		local shoulder = self._lastState["Shoulder"]
		local elbow = self._lastState["Elbow"]
		local wrist = self._lastState["Wrist"]
		if not shoulder and elbow and wrist then
			return
		end

		if RunService:IsRunning() then
			if USE_MOTOR_6D_RAW then
				shoulder.Transform = self._shoulderTransform
				elbow.Transform = self._elbowTransform
				wrist.Transform = self._wristTransform
			else
				error("Should not be called")
			end
		else
			-- Test mode/story mode
			if not self._initTest then
				self._initTest = true
				self._testDefaultShoulderC0 = shoulder.C0
				self._testDefaultElbowC0 = elbow.C0
				self._testDefaultWristC0 = wrist.C0
			end

			shoulder.C0 = self._testDefaultShoulderC0 * self._shoulderTransform
			elbow.C0 = self._testDefaultElbowC0 * self._elbowTransform
			wrist.C0 = self._testDefaultWristC0 * self._wristTransform
		end
	end
end

if USE_OLD_IK_SYSTEM then
	function ArmIKBase:Update()
		if self:_oldUpdatePoint() then
			local shoulderXAngle = self._shoulderXAngle
			local elbowXAngle = self._elbowXAngle

			local yrot = CFrame.new(Vector3.zero, self._offset)

			self._shoulderTransform = (yrot * CFA_90X * CFrame.Angles(shoulderXAngle, 0, 0)) --:inverse()
			self._elbowTransform = CFrame.Angles(elbowXAngle, 0, 0)
			self._wristTransform = CFrame.new()

			self:UpdateTransformOnly()
		end
	end
else
	function ArmIKBase:Update()
		if self:_newUpdate() then
			self:UpdateTransformOnly()
		end
	end
end

function ArmIKBase:_oldUpdatePoint()
	local grip = self._grips[1]
	if not grip then
		self:_clear()
		return false
	end

	if not self:_oldCalculatePoint(grip.attachment.WorldPosition) then
		self:_clear()
		return false
	end

	return true
end

function ArmIKBase:_clear()
	self._offset = nil
	self._elbowTransform = nil
	self._shoulderTransform = nil
	self._wristTransform = nil
end

function ArmIKBase:_newUpdate()
	local grip = self._grips[1]
	if not (grip and self._lastState) then
		self._elbowTransform = nil
		self._shoulderTransform = nil
		self._wristTransform = nil
		return false
	end

	local targetCFrame = grip.attachment.WorldCFrame

	local upperTorsoShoulderRigAttachment = self._lastState["UpperTorsoShoulderRigAttachment"]
	local upperArmShoulderRigAttachment = self._lastState["UpperArmShoulderRigAttachment"]
	local upperArmElbowRigAttachment = self._lastState["UpperArmElbowRigAttachment"]
	local lowerArmElbowRigAttachment = self._lastState["LowerArmElbowRigAttachment"]
	local lowerArmWristRigAttachment = self._lastState["LowerArmWristRigAttachment"]
	local handWristRigAttachment = self._lastState["HandWristRigAttachment"]
	local handGripAttachment = self._lastState["HandGripAttachment"]

	if
		not (
			upperTorsoShoulderRigAttachment
			and upperArmShoulderRigAttachment
			and upperArmElbowRigAttachment
			and lowerArmElbowRigAttachment
			and lowerArmWristRigAttachment
			and handWristRigAttachment
			and handGripAttachment
		)
	then
		return false
	end

	local elbowOffset = upperArmElbowRigAttachment.Position - upperArmShoulderRigAttachment.Position
	local wristOffset = lowerArmWristRigAttachment.Position - lowerArmElbowRigAttachment.Position
	local handOffset = handGripAttachment.Position - handWristRigAttachment.Position

	-- TODO: Cache config
	local config = LimbIKUtils.createConfig(elbowOffset, wristOffset + handOffset, 1)
	local relTargetCFrame = upperTorsoShoulderRigAttachment.WorldCFrame:toObjectSpace(targetCFrame)

	-- TODO: Allow configuration
	local ELBOW_ANGLE = math.rad(20)
	local shoulderQFrame, elbowQFrame, wristQFrame = LimbIKUtils.solveLimb(
		config,
		QFrame.fromCFrameClosestTo(relTargetCFrame, QFrame.new()),
		self._direction * ELBOW_ANGLE
	)

	self._shoulderTransform = QFrame.toCFrame(shoulderQFrame)
	self._elbowTransform = QFrame.toCFrame(elbowQFrame)
	self._wristTransform = QFrame.toCFrame(wristQFrame)

	return true
end

function ArmIKBase:_oldCalculatePoint(targetPositionWorld)
	if not self._lastState then
		return false
	end

	local shoulder = self._lastState["Shoulder"]
	local elbow = self._lastState["Elbow"]
	local wrist = self._lastState["Wrist"]
	local gripAttachment = self._lastState["HandGripAttachment"]
	if not (shoulder and elbow and wrist and gripAttachment) then
		return false
	end

	if not (shoulder.Part0 and elbow.Part0 and elbow.Part1) then
		return false
	end

	local base = shoulder.Part0.CFrame * (self._testDefaultShoulderC0 or shoulder.C0)
	local elbowCFrame = elbow.Part0.CFrame * (self._testDefaultElbowC0 or elbow.C0)
	local wristCFrame = elbow.Part1.CFrame * (self._testDefaultWristC0 or wrist.C0)

	local r0 = (base.Position - elbowCFrame.Position).Magnitude
	local r1 = (elbowCFrame.Position - wristCFrame.Position).Magnitude

	r1 = r1 + (gripAttachment.WorldPosition - wristCFrame.Position).Magnitude

	local offset = base:pointToObjectSpace(targetPositionWorld)
	local d = offset.Magnitude

	if d > (r0 + r1) then -- Case: Circles are seperate
		d = r0 + r1
	end

	if d == 0 then
		return false
	end

	local baseAngle = Math.lawOfCosines(r0, d, r1)
	local elbowAngle = Math.lawOfCosines(r1, r0, d) -- Solve for angle across from d

	if not (baseAngle and elbowAngle) then
		return false
	end

	elbowAngle = (elbowAngle - math.pi)
	if elbowAngle > -math.pi / 32 then -- Force a bit of bent elbow
		elbowAngle = -math.pi / 32
	end

	self._shoulderXAngle = -baseAngle
	self._elbowXAngle = -elbowAngle
	self._offset = offset.unit * d

	return true
end

return ArmIKBase
