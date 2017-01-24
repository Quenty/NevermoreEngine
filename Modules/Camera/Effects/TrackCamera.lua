-- TrackCamera.lua
-- Intent: Track a current element

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
	
local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera      = LoadCustomLibrary("SummedCamera")

local TrackCamera = {}
TrackCamera.ClassName = "TrackCamera"
TrackCamera.FieldOfView = 0

function TrackCamera.new(CameraSubject)
	-- @param [CameraSubject] The CameraSubject to look at. A ROBLOX part of ROBLOX model
	
	local self = setmetatable({}, TrackCamera)

	self.CameraSubject = CameraSubject

	return self
end

function TrackCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function TrackCamera:__newindex(Index, Value)
	if Index == "CameraSubject" then
		assert(type(Value) == "userdata" or type(Value) == "nil", "CameraSubject must be a ROBLOX Model or ROBLOX Part or nil")
		
		if type(Value) == "userdata" then
			assert(Value:IsA("Model") or Value:IsA("BasePart"), "CameraSubject must be a Model or BasePart")
		end

		rawset(self, Index, Value)
	elseif Index == "FieldOfView" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of TrackCamera")
	end
end

function TrackCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local CameraSubject = self.CameraSubject
		local State = CameraState.new()
		State.FieldOfView = self.FieldOfView

		if CameraSubject then
			if CameraSubject:IsA("Model") then
				State.CoordinateFrame = CameraSubject.PrimaryPart and CameraSubject.PrimaryPart:GetRenderCFrame() or CameraSubject:GetPrimaryPartCFrame()
			elseif CameraSubject:IsA("BasePart") then
				State.CoordinateFrame = CameraSubject:GetRenderCFrame()
			end
		end

		return State
	else
		return TrackCamera[Index]
	end
end

return TrackCamera
