--[=[
	Handles repliation and aiming of the local player's character for
	IK.

	@client
	@class IKRigAimerLocalPlayer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local CameraStackService = require("CameraStackService")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

local MAX_AGE_FOR_AIM_DATA = 0.2
local DEFAULT_REPLICATION_RATE = 1.3

local IKRigAimerLocalPlayer = setmetatable({}, BaseObject)
IKRigAimerLocalPlayer.ClassName = "IKRigAimerLocalPlayer"
IKRigAimerLocalPlayer.__index = IKRigAimerLocalPlayer

--[=[
	Constructs a new IKRigAimerLocalPlayer. Should not be used directly.
	See [IKServiceClient] for the correct usage.

	@param serviceBag ServiceBag
	@param ikRig IKRigClient
	@return IKRigAimerLocalPlayer
]=]
function IKRigAimerLocalPlayer.new(serviceBag, ikRig)
	local self = setmetatable(BaseObject.new(), IKRigAimerLocalPlayer)

	self._cameraStackService = serviceBag:GetService(CameraStackService)
	self._ikRig = ikRig or error("No ikRig")

	self._lastUpdate = 0
	self._lastReplication = 0
	self._lookAround = true

	self._aimData = nil

	self._replicationRate = DEFAULT_REPLICATION_RATE
	self._replicationRates = {}

	return self
end

--[=[
	Sets whether the local player should look around automatically.
	@param lookAround boolean
]=]
function IKRigAimerLocalPlayer:SetLookAround(lookAround: boolean)
	assert(type(lookAround) == "boolean", "Bad lookAround")

	self._lookAround = lookAround
end

--[=[
	Sets the aim position for the local player for this frame. See [IKAimPositionPriorites].

	@param position Vector3? -- May be nil to say to aim at nothing
	@param optionalPriority number
]=]
function IKRigAimerLocalPlayer:SetAimPosition(position, optionalPriority)
	optionalPriority = optionalPriority or IKAimPositionPriorites.DEFAULT

	if self._aimData and (os.clock() - self._aimData.timeStamp) < MAX_AGE_FOR_AIM_DATA then
		if self._aimData.priority > optionalPriority then
			return -- Don't overwrite
		end
	end

	self._aimData = {
		priority = optionalPriority,
		position = position, -- May be nil
		timeStamp = os.clock(),
	}
end

function IKRigAimerLocalPlayer:PushReplicationRate(replicateRate: number)
	assert(type(replicateRate) == "number", "Bad replicateRate")

	local data = {
		replicateRate = replicateRate,
	}

	table.insert(self._replicationRates, data)
	self:_updateReplicationRate()

	if #self._replicationRates >= 10 then
		warn("[IKRigAimerLocalPlayer] - More than 10 replication rates stored, memory leak possible")
	end

	return function()
		if not self.Destroy then
			return
		end

		local index = table.find(self._replicationRates, data)
		if index then
			table.remove(self._replicationRates, index)
			self:_updateReplicationRate()
		end
	end
end

function IKRigAimerLocalPlayer:_updateReplicationRate()
	local best = nil
	for _, rateData in self._replicationRates do
		local rate = rateData.replicateRate
		if not best or rate < best then
			best = rate
		end
	end

	self._replicationRate = best or DEFAULT_REPLICATION_RATE
end

--[=[
	Gets the current aim position.
	@return Vector3?
]=]
function IKRigAimerLocalPlayer:GetAimPosition()
	if self._aimData and (os.clock() - self._aimData.timeStamp) < MAX_AGE_FOR_AIM_DATA then
		-- If we have aim data within the last 0.2 seconds start pointing at that
		return self._aimData.position -- May be nil
	end

	if not self._lookAround then
		return nil
	end

	local humanoid = self._ikRig:GetHumanoid()

	local cameraCFrame = self._cameraStackService:GetRawDefaultCamera().CameraState.CFrame
	local characterCFrame = humanoid.RootPart and humanoid.RootPart.CFrame
	local multiplier = 1000

	-- Make the character look at the camera instead of trying to turn 180
	if characterCFrame then
		local relative = cameraCFrame:vectorToObjectSpace(characterCFrame.lookVector)

		-- Angle between forward vector of character and the camera (only Y axis)
		local angle = math.acos(relative.Z)

		if angle < math.rad(60) then
			multiplier = -multiplier
		end
	end

	local direction = cameraCFrame.lookVector * multiplier

	return cameraCFrame.Position + direction
end

--[=[
	Updates the aimer on stepped.
	@private
]=]
function IKRigAimerLocalPlayer:UpdateStepped()
	if (os.clock() - self._lastUpdate) <= 0.05 then
		return
	end

	local aimPosition = self:GetAimPosition()

	self._lastUpdate = os.clock()
	local torso = self._ikRig:GetTorso()
	if torso then
		torso:Point(aimPosition)
	end

	-- Filter replicate
	if (os.clock() - self._lastReplication) > self._replicationRate then
		self._lastReplication = os.clock()
		self._ikRig:FireSetAimPosition(aimPosition)
	end
end

return IKRigAimerLocalPlayer
