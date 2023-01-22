--[=[
	@class RagdollMotorUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AttributeUtils = require("AttributeUtils")
local CharacterUtils = require("CharacterUtils")
local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local QFrame = require("QFrame")
local R15Utils = require("R15Utils")
local RagdollConstants = require("RagdollConstants")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")
local Spring = require("Spring")
local RagdollCollisionUtils = require("RagdollCollisionUtils")
local Motor6DStackInterface = require("Motor6DStackInterface")
local Rx = require("Rx")

local RagdollMotorUtils = {}

-- For easier debugging
local DEFAULT_SPRING_SPEED = 20

local R6_MOTORS = {
	{
		partName = "Torso";
		motorName = "Root";
		isRootJoint = true;
	};
	{
		partName = "Torso";
		motorName = "Neck";
	};
	{
		partName = "Torso";
		motorName = "Left Shoulder";
	};
	{
		partName = "Torso";
		motorName = "Right Shoulder";
	};
	{
		partName = "Torso";
		motorName = "Left Hip";
	};
	{
		partName = "Torso";
		motorName = "Right Hip";
	};
}

local R15_MOTORS = {
	{
		partName = "LowerTorso";
		motorName = "Root";
		isRootJoint = true;
	};
	{
		partName = "UpperTorso";
		motorName = "Waist";
	};
	{
		partName = "Head";
		motorName = "Neck";
	};
	{
		partName = "LeftUpperArm";
		motorName = "LeftShoulder";
	};
	{
		partName = "LeftLowerArm";
		motorName = "LeftElbow";
	};
	{
		partName = "LeftHand";
		motorName = "LeftWrist";
	};
	{
		partName = "RightUpperArm";
		motorName = "RightShoulder";
	};
	{
		partName = "RightLowerArm";
		motorName = "RightElbow";
	};
	{
		partName = "RightHand";
		motorName = "RightWrist";
	};
	{
		partName = "LeftUpperLeg";
		motorName = "LeftHip";
	};
	{
		partName = "LeftLowerLeg";
		motorName = "LeftKnee";
	};
	{
		partName = "LeftFoot";
		motorName = "LeftAnkle";
	};
	{
		partName = "RightUpperLeg";
		motorName = "RightHip";
	};
	{
		partName = "RightLowerLeg";
		motorName = "RightKnee";
	};
	{
		partName = "RightFoot";
		motorName = "RightAnkle";
	};
}

local ROOT_JOINT_CACHE = {}

function RagdollMotorUtils.getFirstRootJointData(rigType)
	if ROOT_JOINT_CACHE[rigType] then
		return ROOT_JOINT_CACHE[rigType]
	end

	for _, item in pairs(RagdollMotorUtils.getMotorData(rigType)) do
		if item.isRootJoint then
			ROOT_JOINT_CACHE[rigType] = item
			return item
		end
	end

	error("Could not find root joint data")
end

function RagdollMotorUtils.getMotorData(rigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return R15_MOTORS
	elseif rigType == Enum.HumanoidRigType.R6 then
		return R6_MOTORS
	else
		error(("[RagdollMotorUtils] - Unknown rigType %q"):format(tostring(rigType)))
	end
end

function RagdollMotorUtils.initMotorAttributes(character, rigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	for _, data in pairs(RagdollMotorUtils.getMotorData(rigType)) do
		local motor = R15Utils.getRigMotor(character, data.partName, data.motorName)
		if motor then
			AttributeUtils.initAttribute(motor, RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false)
			AttributeUtils.initAttribute(motor, RagdollConstants.RETURN_SPRING_SPEED_ATTRIBUTE, DEFAULT_SPRING_SPEED)
		end
	end
end

function RagdollMotorUtils.setupAnimatedMotor(character, part)
	local maid = Maid.new()

	-- make this stuff not physics collide with our own rig
	-- O(n^2)
	maid:GiveTask(RagdollCollisionUtils.preventCollisionAmongOthers(character, part))

	return maid
end

function RagdollMotorUtils.setupRagdollRootPartMotor(motor, part0, part1)
	local maid = Maid.new()

	local lastTransformSpring = Spring.new(QFrame.fromCFrameClosestTo(motor.Transform, QFrame.new()))
	lastTransformSpring.t = QFrame.new()

	-- replacing this weld ensures interpolation for some reason
	local weldContainer = Instance.new("Camera")
	weldContainer.Name = "TempWeldContainer"
	weldContainer.Parent = part0
	maid:GiveTask(weldContainer)

	local function setupWeld(weldType)
		local weldMaid = Maid.new()

		local weld = Instance.new(weldType)
		weld.Name = "TempRagdollWeld"
		weld.Part0 = part0
		weld.Part1 = part1
		weldMaid:GiveTask(weld)

		-- Inserted C1/C0 here
		weldMaid:GiveTask(Rx.combineLatest({
			C0 = RxInstanceUtils.observeProperty(motor, "C0");
			Transform = RxInstanceUtils.observeProperty(motor, "Transform");
		}):Subscribe(function(innerState)
			weld.C0 = innerState.C0 * innerState.Transform
		end))
		weldMaid:GiveTask(RxInstanceUtils.observeProperty(motor, "C1"):Subscribe(function(c1)
			weld.C1 = c1
		end))
		weld.Parent = weldContainer

		return weldMaid
	end

	if CharacterUtils.getPlayerFromCharacter(part0) then
		-- Swap from choppy to interpolation
		maid._weld = setupWeld("Motor6D")
		maid:GiveTask(task.delay(0.25, function()
			maid._weld = setupWeld("Weld")
		end))
	else
		-- Smooth all the way! (Probably NPC)
		maid._weld = setupWeld("Weld")
	end

	maid:GiveTask(RxAttributeUtils.observeAttribute(motor, RagdollConstants.RETURN_SPRING_SPEED_ATTRIBUTE, DEFAULT_SPRING_SPEED)
		:Subscribe(function(speed)
			lastTransformSpring.s = speed
		end))

	-- Lerp smoothly to 0 to avoid jarring camera.
	maid:GiveTask(RunService.Stepped:Connect(function()
		local target = QFrame.toCFrame(lastTransformSpring.p)
		if target then
			motor.Transform = target
		end
	end))

	motor.Enabled = false

	maid:GiveTask(function()
		motor.Enabled = true
	end)

	return maid
end

function RagdollMotorUtils.setupRagdollMotor(motor, part0, part1)
	local maid = Maid.new()

	motor.Enabled = false
	maid:GiveTask(function()
		local implemention = Motor6DStackInterface:FindFirstImplementation(motor)
		if implemention then
			local initialTransform = (part0.CFrame * motor.C0):toObjectSpace(part1.CFrame * motor.C1)
			local speed = AttributeUtils.getAttribute(motor, RagdollConstants.RETURN_SPRING_SPEED_ATTRIBUTE, DEFAULT_SPRING_SPEED)

			implemention:TransformFromCFrame(initialTransform, speed)
		end

		motor.Enabled = true
	end)

	maid:GiveTask(RunService.Stepped:Connect(function()
		motor.Transform = CFrame.new()
	end))

	return maid
end

function RagdollMotorUtils.suppressJustRootPart(character, rigType)
	local data = RagdollMotorUtils.getFirstRootJointData(rigType)

	local observable = RxR15Utils.observeRigMotorBrio(character, data.partName, data.motorName):Pipe({
		RxBrioUtils.switchMapBrio(function(motor)
			return RxBrioUtils.flatCombineLatest({
				motor = motor;
				part0 = RxInstanceUtils.observeProperty(motor, "Part0");
				part1 = RxInstanceUtils.observeProperty(motor, "Part1");
				isAnimated = RxAttributeUtils.observeAttribute(motor, RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false);
			})
		end);
	})

	local topMaid = Maid.new()

	topMaid:GiveTask(observable:Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local state = brio:GetValue()
		local motorMaid = brio:ToMaid()

		if not (state.motor and state.part0 and state.part1) then
			return
		end

		if state.isAnimated then
			motorMaid._current = RagdollMotorUtils.setupAnimatedMotor(character, state.part1)
		else
			motorMaid._current = RagdollMotorUtils.setupRagdollRootPartMotor(state.motor, state.part0, state.part1)
		end
	end))

	return topMaid
end

function RagdollMotorUtils.suppressMotors(character, rigType, velocityReadings)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local topMaid = Maid.new()

	for _, data in pairs(RagdollMotorUtils.getMotorData(rigType)) do
		local observable = RxR15Utils.observeRigMotorBrio(character, data.partName, data.motorName):Pipe({
			RxBrioUtils.switchMapBrio(function(motor)
				return RxBrioUtils.flatCombineLatest({
					motor = motor;
					part0 = RxInstanceUtils.observeProperty(motor, "Part0");
					part1 = RxInstanceUtils.observeProperty(motor, "Part1");
					isAnimated = RxAttributeUtils.observeAttribute(motor, RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false);
				})
			end);
		})

		topMaid:GiveTask(observable:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local state = brio:GetValue()
			local motorMaid = brio:ToMaid()

			if not (state.motor and state.part0 and state.part1) then
				return
			end

			if state.isAnimated then
				motorMaid._current = RagdollMotorUtils.setupAnimatedMotor(character, state.part1)
			else
				if data.isRootJoint then
					motorMaid._current = RagdollMotorUtils.setupRagdollRootPartMotor(state.motor, state.part0, state.part1)
				else
					motorMaid._current = RagdollMotorUtils.setupRagdollMotor(state.motor, state.part0, state.part1)
				end

				-- Note animator:ApplyJointVelocities fails. Do this manually.
				-- We only want to do this on the network owner.
				if RagdollMotorUtils.guessIfNetworkOwner(state.part1) then
					task.defer(function()
						-- use physics time
						local passed = time() - velocityReadings.readingTimePhysics
						if passed <= 0.1 then
							local rotVelocity = velocityReadings.rotation[data]
							if rotVelocity then
								state.part1.RotVelocity += rotVelocity
							end

							local velocity = velocityReadings.linear[data]
							if velocity then
								state.part1.Velocity += velocity
							end
						end
					end)
				end
			end
		end))
	end

	return topMaid
end

function RagdollMotorUtils.guessIfNetworkOwner(part)
	local currentNetworkOwner
	local expectedNetworkOwner = Players.LocalPlayer

	-- hopefully someday GetNetworkOwner() works on the client
	local ok = pcall(function()
		currentNetworkOwner = part:GetNetworkOwner()
	end)
	if ok then
		return currentNetworkOwner == expectedNetworkOwner
	end

	return CharacterUtils.getPlayerFromCharacter(part) == expectedNetworkOwner
end

function RagdollMotorUtils.promiseVelocityRecordings(character, rigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local parts = {}

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return Promise.rejected("No humanoid root part")
	end

	local initialRootPartCFrame = rootPart.CFrame
	for _, data in pairs(RagdollMotorUtils.getMotorData(rigType)) do
		local motor = R15Utils.getRigMotor(character, data.partName, data.motorName)
		if motor then
			local part0 = motor.Part0
			local part1 = motor.Part1
			if part0 and part1 then
				parts[data] = {
					motor = motor;
					part0 = part0;
					part1 = part1;
					relCFrame = initialRootPartCFrame:toObjectSpace(part1.CFrame);
				}
			end
		end
	end

	return Promise.spawn(function(resolve, _reject)
		local dt = RagdollMotorUtils.yieldUntilStepped()

		-- Do this relative to the root part so we only get animation
		-- physics data
		local newRootPartCFrame = rootPart.CFrame

		local result = {
			readingTimePhysics = time();
			linear = {};
			rotation = {};
		}

		for data, info in pairs(parts) do
			local motor = R15Utils.getRigMotor(character, data.partName, data.motorName)

			-- Validate all the same
			if info.motor == motor and info.part0 == motor.Part0 and info.part1 == motor.Part1 then
				local linear = newRootPartCFrame:pointToObjectSpace(info.part1.Position) - info.relCFrame.p
				result.linear[data] = newRootPartCFrame:vectorToWorldSpace(linear/dt)

				local change = info.relCFrame:toObjectSpace(newRootPartCFrame:toObjectSpace(info.part1.CFrame))

				-- assume that we're XYZ ordered
				local x, y, z = change:ToEulerAnglesXYZ()

				local vector = newRootPartCFrame:vectorToWorldSpace(Vector3.new(x, y, z))
				result.rotation[data] = vector/dt
			end
		end

		resolve(result)
	end)
end

function RagdollMotorUtils.yieldUntilStepped()
	local start = time()
	local dt
	repeat
		-- Apparently this is an issue...
		RunService.Stepped:Wait()
		RunService.Stepped:Wait()
		dt = time() - start
	until dt > 0
	return dt
end

return RagdollMotorUtils