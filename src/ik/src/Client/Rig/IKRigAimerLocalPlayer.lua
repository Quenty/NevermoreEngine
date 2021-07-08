---
-- @classmod IKRigAimerLocalPlayer
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local CameraStackService = require("CameraStackService")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

local MAX_AGE_FOR_AIM_DATA = 0.2
local REPLICATION_RATE = 1.3

local IKRigAimerLocalPlayer = setmetatable({}, BaseObject)
IKRigAimerLocalPlayer.ClassName = "IKRigAimerLocalPlayer"
IKRigAimerLocalPlayer.__index = IKRigAimerLocalPlayer

function IKRigAimerLocalPlayer.new(ikRig, remoteEvent)
	local self = setmetatable(BaseObject.new(), IKRigAimerLocalPlayer)

	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._ikRig = ikRig or error("No ikRig")

	self._lastUpdate = 0
	self._lastReplication = 0
	self._aimData = nil
	self._noDefault = false

	return self
end

function IKRigAimerLocalPlayer:SetNoDefaultIK(noDefault)
	self._noDefault = noDefault
end

-- @param position May be nil
function IKRigAimerLocalPlayer:SetAimPosition(position, optionalPriority)
	optionalPriority = optionalPriority or IKAimPositionPriorites.DEFAULT

	if self._aimData and (tick() - self._aimData.timeStamp) < MAX_AGE_FOR_AIM_DATA then
		if self._aimData.priority > optionalPriority then
			return -- Don't overwrite
		end
	end

	self._aimData = {
		priority = optionalPriority;
		position = position; -- May be nil
		timeStamp = tick();
	}
end

function IKRigAimerLocalPlayer:GetAimDirection()
	if self._aimData and (tick() - self._aimData.timeStamp) < MAX_AGE_FOR_AIM_DATA then
			-- If we have aim data within the last 0.2 seconds start pointing at that
		return self._aimData.position -- May be nil
	end

	if self._noDefault then
		return nil
	end

	local humanoid = self._ikRig:GetHumanoid()

	local cameraCFrame = CameraStackService:GetRawDefaultCamera().CameraState.CFrame
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

	return cameraCFrame.p + direction
end


function IKRigAimerLocalPlayer:UpdateStepped()
	if (tick() - self._lastUpdate) <= 0.05 then
		return
	end

	local aimDirection = self:GetAimDirection()

	self._lastUpdate = tick()
	local torso = self._ikRig:GetTorso()
	if torso then
		torso:Point(aimDirection)
	end

	-- Filter replicate
	if (tick() - self._lastReplication) > REPLICATION_RATE then
		self._lastReplication = tick()
		self._remoteEvent:FireServer(aimDirection)
	end
end

return IKRigAimerLocalPlayer