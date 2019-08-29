--- Handles IK for local client
-- @classmod IKServiceClient

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraStackService = require("CameraStackService")
local IKAimPositionPriorites = require("IKAimPositionPriorites")
local IKConstants = require("IKConstants")
local IKRig = require("IKRig")
local Maid = require("Maid")
local promiseChild = require("promiseChild")

local MAX_AGE_FOR_AIM_DATA = 0.2

local IKServiceClient = {}

function IKServiceClient:Init()
	self._maid = Maid.new()

	-- Hopefully doesn't leak
	self._rigMetadata = setmetatable({}, {__mode = 'k'})
	self._rigs = {}

	self._maid._stepped = RunService.Stepped:Connect(function()
		self:_update()
	end)

	self:_setupLocalPlayer()

	self._remoteEvent = require.GetRemoteEvent(IKConstants.REMOTE_EVENT_NAME)
	self._maid:GiveTask(self._remoteEvent.OnClientEvent:Connect(function(...)
		self:_handleClientEvent(...)
	end))
end

function IKServiceClient:GetRig(humanoid)
	if not self:_isValid(humanoid) then
		return nil
	end

	if self._rigs[humanoid] then
		return self._rigs[humanoid]
	end

	local rig = IKRig.new(humanoid)
	self._rigs[humanoid] = rig
	self._maid[humanoid] = rig

	return rig
end

--- Exposed API for guns and other things to start setting aim position
--- which will override for a limited time
function IKServiceClient:SetAimPosition(position, optionalPriority)
	optionalPriority = optionalPriority or IKAimPositionPriorites.DEFAULT

	if self._aimData and (tick() - self._aimData.TimeStamp) < MAX_AGE_FOR_AIM_DATA then
		if self._aimData.Priority > optionalPriority then
			return -- Don't overwrite
		end
	end

	self._aimData = {
		Priority = optionalPriority;
		Position = position;
		TimeStamp = tick();
	}

	return
end

function IKServiceClient:GetAimDirection(humanoid)
	if self._aimData and (tick() - self._aimData.TimeStamp) < MAX_AGE_FOR_AIM_DATA then
			-- If we have aim data within the last 0.2 seconds start pointing at that
		return self._aimData.Position
	end

	local cameraCFrame = CameraStackService:GetRawDefaultCamera().CameraState.CFrame
	local characterCFrame = humanoid.RootPart and humanoid.RootPart.CFrame
	local multiplier = 1000

	-- Make the character look at the camera instead of trying to turn 180
	if characterCFrame then
		local relative = cameraCFrame:vectorToObjectSpace(characterCFrame.lookVector)

		-- Angle between forward vector of character and the camera (only Y axis)
		local angle = math.acos(relative.Z)


		if angle < math.pi/3 then
			multiplier = -multiplier
		end
	end

	return cameraCFrame.p + cameraCFrame.lookVector * multiplier
end

function IKServiceClient:_setupLocalPlayer()
	local localPlayer = Players.LocalPlayer
	self._maid:GiveTask(localPlayer.CharacterAdded:Connect(function(Character)
		self:_onLocalCharacterAdded(Character)
	end))

	spawn(function()
		if localPlayer.Character then
			self:_onLocalCharacterAdded(localPlayer.Character)
		end
	end)
end

function IKServiceClient:_onLocalHumanoidAdd(maid, humanoid)
	local lastUpdate = 0
	local lastReplication = 0

	local function update()
		local rig = self:GetRig(humanoid)
		if not rig then
			--warn("[IKServiceClient] - No rig for local client")
			return
		end

		if (tick() - lastUpdate) <= 0.05 then
			return
		end
		lastUpdate = tick()

		local aimDirection = self:GetAimDirection(humanoid)
		local torso = rig:GetTorso()
		if torso then
			torso:Point(aimDirection)
		end

		-- Filter replicate
		if (tick() - lastReplication) <= 1/3 then
			return
		end
		lastReplication = tick()
		self._remoteEvent:FireServer(aimDirection)
	end
	self._characterSteppedFunction = update

	maid:GiveTask(humanoid.Died:Connect(function()
		maid:DoCleaning()
	end))

	maid:GiveTask(function()
		if self._characterSteppedFunction == update then
			self._characterSteppedFunction = nil
		end
	end)
end

function IKServiceClient:_onLocalCharacterAdded(character)
	self._maid._characterMaid = nil -- Cleanup first!

	local maid = Maid.new()
	maid:GivePromise(promiseChild(character, "Humanoid", 5)):Then(function(humanoid)
		self:_onLocalHumanoidAdd(maid, humanoid)
	end, function(err)
		if err then
			warn("[IKServiceClient._onLocalCharacterAdded] - No humanoid loaded", err)
		end
	end)
	self._maid._characterMaid = maid
end

function IKServiceClient:_handleClientEvent(request, ...)
	assert(type(request) == "string")

	if request == "UpdateRig" then
		self:_updateRig(...)
	elseif request == "RemoveRig" then
		self:_removeRig(...)
	else
		warn(("[IKServiceClient._handleClientEvent] - Bad request %q"):format(tostring(request)))
	end
end

function IKServiceClient:_updateRig(humanoid, target)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))
	assert(typeof(target) == "Vector3")

	if not humanoid then
		warn("[IKServiceClient._handleClientEvent] - No humanoid found. Cannot PointTorso.")
		return
	end

	local rig = self:GetRig(humanoid)
	if not rig then
		warn("[IKServiceClient._handleClientEvent] - No rig found for humanoid. Cannot PointTorso.")
		return
	end

	local torso = rig:GetTorso()
	if not torso then
		return
	end

	torso:Point(target)
end

function IKServiceClient:_isValid(humanoid)
	return humanoid:IsDescendantOf(game)
		and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

function IKServiceClient:_update()
	debug.profilebegin("IKUpdate")
	if self._characterSteppedFunction then
		self:_characterSteppedFunction()
	end

	local camPosition = Workspace.CurrentCamera.CFrame.p

	for humanoid, rig in pairs(self._rigs) do
		debug.profilebegin("RigUpdate")

		if self:_isValid(humanoid) then
			local lastUpdateTime = self._rigMetadata[rig]
			if not lastUpdateTime then
				lastUpdateTime = 0
			end

			local rootPosition = humanoid.RootPart and humanoid.RootPart.Position
			local distance = (camPosition - rootPosition).Magnitude
			local updateRate

			if distance < 50 then
				updateRate = 0
			elseif distance < 300 then
				updateRate = (distance-50)/250
			else
				updateRate = 1
			end

			updateRate = updateRate * 0.5

			if (tick() - lastUpdateTime) >= updateRate then
				lastUpdateTime = tick()
				rig:Update() -- Update actual rig
			else
				rig:UpdateTransformOnly()
			end

			self._rigMetadata[rig] = lastUpdateTime
		else
			self:_removeRig(humanoid)
		end

		debug.profileend()
	end
	debug.profileend()
end

function IKServiceClient:_removeRig(humanoid)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))

	self._rigs[humanoid] = nil
	self._maid[humanoid] = nil
end

return IKServiceClient