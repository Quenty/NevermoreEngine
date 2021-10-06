--- Ragdolls the humanoid on fall
-- @classmod BindableRagdollHumanoidOnFall

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local FRAMES_TO_EXAMINE = 8
local FRAME_TIME = 0.1
local RAGDOLL_DEBOUNCE_TIME = 1
local REQUIRED_MAX_FALL_VELOCITY = -30

local BindableRagdollHumanoidOnFall = setmetatable({}, BaseObject)
BindableRagdollHumanoidOnFall.ClassName = "BindableRagdollHumanoidOnFall"
BindableRagdollHumanoidOnFall.__index = BindableRagdollHumanoidOnFall

function BindableRagdollHumanoidOnFall.new(humanoid, ragdollBinder)
	local self = setmetatable(BaseObject.new(humanoid), BindableRagdollHumanoidOnFall)

	self._ragdollBinder = assert(ragdollBinder, "Bad ragdollBinder")

	self.ShouldRagdoll = Instance.new("BoolValue")
	self.ShouldRagdoll.Value = false
	self._maid:GiveTask(self.ShouldRagdoll)

	-- Setup Ragdoll
	self:_initLastVelocityRecords()
	self._lastRagDollTime = 0

	local alive = true
	self._maid:GiveTask(function()
		alive = false
	end)

	task.spawn(function()
		task.wait(math.random()*FRAME_TIME) -- Apply jitter
		while alive do
			self:_updateVelocity()
			task.wait(FRAME_TIME)
		end
	end)

	self._maid:GiveTask(self._ragdollBinder:ObserveInstance(self._obj, function(class)
		if not class then
			self._lastRagDollTime = tick()
			self.ShouldRagdoll.Value = false
		end
	end))

	return self
end

function BindableRagdollHumanoidOnFall:_initLastVelocityRecords()
	self._lastVelocityRecords = {}
	for _ = 1, FRAMES_TO_EXAMINE + 1 do -- Add an extra frame because we remove before inserting
		table.insert(self._lastVelocityRecords, Vector3.new())
	end
end

function BindableRagdollHumanoidOnFall:_getLargestSpeedInRecords()
	local largestSpeed = -math.huge

	for _, velocityRecord in pairs(self._lastVelocityRecords) do
		local speed = velocityRecord.magnitude
		if speed > largestSpeed then
			largestSpeed = speed
		end
	end

	return largestSpeed
end

function BindableRagdollHumanoidOnFall:_ragdollFromFall()
	self.ShouldRagdoll.Value = true

	task.spawn(function()
		while self.Destroy
			and self:_getLargestSpeedInRecords() >= 3
			and self.ShouldRagdoll.Value do
			task.wait(0.05)
		end

		if self.Destroy and self.ShouldRagdoll.Value then
			task.wait(0.75)
		end

		if self.Destroy and self._obj.Health > 0 then
			self.ShouldRagdoll.Value = false
		end
	end)
end

function BindableRagdollHumanoidOnFall:_updateVelocity()
	table.remove(self._lastVelocityRecords, 1)

	local rootPart = self._obj.RootPart
	if not rootPart then
		table.insert(self._lastVelocityRecords, Vector3.new())
		return
	end

	local currentVelocity = rootPart.Velocity

	local fellForAllFrames = true
	local mostNegativeVelocityY = math.huge
	for _, velocityRecord in pairs(self._lastVelocityRecords) do
		if velocityRecord.y >= -2 then
			fellForAllFrames = false
			break
		end

		if velocityRecord.y < mostNegativeVelocityY then
			mostNegativeVelocityY = velocityRecord.y
		end
	end

	table.insert(self._lastVelocityRecords, currentVelocity)

	if not fellForAllFrames then
		return
	end

	if mostNegativeVelocityY >= REQUIRED_MAX_FALL_VELOCITY then
		return
	end

	-- print("currentVelocity.magnitude, mostNegativeVelocityY", currentVelocity.magnitude, mostNegativeVelocityY)

	if self._obj.Health <= 0 then
		return
	end

	if self._obj.Sit then
		return
	end

	local currentState = self._obj:GetState()
	if currentState == Enum.HumanoidStateType.Physics
		or currentState == Enum.HumanoidStateType.Swimming then
		return
	end

	if (tick() - self._lastRagDollTime) <= RAGDOLL_DEBOUNCE_TIME then
		return
	end

	self:_ragdollFromFall()
end

return BindableRagdollHumanoidOnFall