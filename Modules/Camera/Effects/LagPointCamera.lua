--- Point a current element but lag behind for a smoother experience
-- @classmod LagPointCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local Spring = require("Spring")

local LagPointCamera = {}
LagPointCamera.ClassName = "LagPointCamera"
LagPointCamera._FocusCamera = nil
LagPointCamera._OriginCamera = nil

---
-- @constructor
-- @param OriginCamera A camera to use
-- @param FocusCamera The Camera to look at.
function LagPointCamera.new(OriginCamera, FocusCamera)
	local self = setmetatable({}, LagPointCamera)

	self.FocusSpring = Spring.new(Vector3.new())
	self.OriginCamera = OriginCamera or error("Must have OriginCamera")
	self.FocusCamera = FocusCamera or error("Must have FocusCamera")
	self.Speed = 10

	return self
end

function LagPointCamera:__add(other)
	return SummedCamera.new(self, other)
end

function LagPointCamera:__newindex(Index, Value)
	if Index == "FocusCamera" then
		rawset(self, "_" .. Index, Value)
		self.FocusSpring.Target = self.FocusCamera.CameraState.Position
		self.FocusSpring.Position = self.FocusSpring.Target
		self.FocusSpring.Velocity = Vector3.new(0, 0, 0)
	elseif Index == "OriginCamera" then
		rawset(self, "_" .. Index, Value)
	elseif Index == "LastFocusUpdate" or Index == "FocusSpring" then
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
			Origin.Position,
			FocusPosition)

		return State
	elseif Index == "FocusPosition" then
		local Delta
		if self.LastFocusUpdate then
			Delta = tick() - self.LastFocusUpdate
		end

		self.LastFocusUpdate = tick()
		self.FocusSpring.Target = self.FocusCamera.CameraState.Position

		if Delta then
			self.FocusSpring:TimeSkip(Delta)
		end

		return self.FocusSpring.Position
	elseif Index == "Speed" or Index == "Damper" or Index == "Velocity" then
		return self.FocusSpring[Index]
	elseif Index == "Origin" then
		return self.OriginCamera.CameraState
	elseif Index == "FocusCamera" or Index == "OriginCamera" then
		return rawget(self, "_" .. Index) or error("Internal error: Index does not exist")
	else
		return LagPointCamera[Index]
	end
end

return LagPointCamera