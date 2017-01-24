-- PointCamera.lua
-- Intent: Point a current element

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera      = LoadCustomLibrary("SummedCamera")

local PointCamera = {}
PointCamera.ClassName = "PointCamera"

function PointCamera.new(OriginCamera, FocusCamera)
	-- @param OriginCamera A camera to use
	-- @param FocusCamera The Camera to look at. 
	
	local self = setmetatable({}, PointCamera)

	self.OriginCamera = OriginCamera or error("Must have OriginCamera")
	self.FocusCamera = FocusCamera or error("Must have OriginCamera")

	return self
end

function PointCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function PointCamera:__newindex(Index, Value)
	if Index == "OriginCamera" or Index == "FocusCamera" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of PointCamera")
	end
end

function PointCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local Origin, Focus = self.Origin, self.Focus

		local State = CameraState.new()
		State.FieldOfView = Origin.FieldOfView + Focus.FieldOfView

		State.CoordinateFrame = CFrame.new(
			Origin.qPosition,
			Focus.qPosition)

		return State
	elseif Index == "Focus" then
		return self.FocusCamera.CameraState
	elseif Index == "Origin" then
		return self.OriginCamera.CameraState
	else
		return PointCamera[Index]
	end
end

return PointCamera
