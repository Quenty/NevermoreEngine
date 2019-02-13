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

function LagPointCamera:__newindex(index, value)
	if index == "FocusCamera" then
		rawset(self, "_" .. index, value)
		self.FocusSpring.Target = self.FocusCamera.CameraState.Position
		self.FocusSpring.Position = self.FocusSpring.Target
		self.FocusSpring.Velocity = Vector3.new(0, 0, 0)
	elseif index == "OriginCamera" then
		rawset(self, "_" .. index, value)
	elseif index == "LastFocusUpdate" or index == "FocusSpring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		self.FocusSpring[index] = value
	else
		error(index .. " is not a valid member of LagPointCamera")
	end
end

function LagPointCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local Origin, FocusPosition = self.Origin, self.FocusPosition

		local State = CameraState.new()
		State.FieldOfView = Origin.FieldOfView + self.FocusCamera.CameraState.FieldOfView

		State.CFrame = CFrame.new(
			Origin.Position,
			FocusPosition)

		return State
	elseif index == "FocusPosition" then
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
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		return self.FocusSpring[index]
	elseif index == "Origin" then
		return self.OriginCamera.CameraState
	elseif index == "FocusCamera" or index == "OriginCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return LagPointCamera[index]
	end
end

return LagPointCamera