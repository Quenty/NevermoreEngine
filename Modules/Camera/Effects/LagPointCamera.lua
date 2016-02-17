local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera      = LoadCustomLibrary("SummedCamera")
local SpringPhysics     = LoadCustomLibrary("SpringPhysics")

local LagPointCamera = {}
LagPointCamera.ClassName = "LagPointCamera"

-- Intent: Point a current element

function LagPointCamera.new(OriginCamera, FocusCamera)
	-- @param OriginCamera A camera to use
	-- @param FocusCamera The Camera to look at. 
	
	local self = setmetatable({}, LagPointCamera)

	self.FocusSpring = SpringPhysics.VectorSpring.New()
	self.OriginCamera = OriginCamera or error("Must have OriginCamera")
	self.FocusCamera = FocusCamera or error("Must have OriginCamera")
	self.Speed = 10

	return self
end

function LagPointCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function LagPointCamera:__newindex(Index, Value)
	if Index == "FocusCamera" then
		rawset(self, Index, Value)
		self.FocusSpring.Target = self.FocusCamera.CameraState.qPosition
		self.FocusSpring.Position = self.FocusSpring.Target
		self.FocusSpring.Velocity = Vector3.new(0, 0, 0)
	elseif Index == "OriginCamera" or Index == "LastFocusUpdate" or Index == "FocusSpring" then
		rawset(self, Index, Value)
	elseif Index == "Speed" or Index == "Damper" or Index == "Velocity" then
		self.FocusSpring[Index] = Value
	else
		error(Index .. " is not a valid member of LagPointCamera")
	end
end

function LagPointCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local Origin, FocusPosition = self.Origin, self.FocusPosition

		local State = CameraState.new()
		State.FieldOfView = Origin.FieldOfView + self.FocusCamera.CameraState.FieldOfView

		State.CoordinateFrame = CFrame.new(
			Origin.qPosition,
			FocusPosition)

		return State
	elseif Index == "FocusPosition" then
		local Delta
		if self.LastFocusUpdate then
			Delta = tick() - self.LastFocusUpdate
		end

		self.LastFocusUpdate = tick()
		self.FocusSpring.Target = self.FocusCamera.CameraState.qPosition

		if Delta then
			self.FocusSpring:TimeSkip(Delta)
		end

		return self.FocusSpring.Position
	elseif Index == "Speed" or Index == "Damper" or Index == "Velocity" then
		return self.FocusSpring[Index]
	elseif Index == "Origin" then
		return self.OriginCamera.CameraState
	else
		return LagPointCamera[Index]
	end
end

return LagPointCamera