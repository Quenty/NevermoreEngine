--- Add another layer of effects that can be faded in/out
-- @classmod FadingCamera

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local Spring = LoadCustomLibrary("Spring")
local SummedCamera = LoadCustomLibrary("SummedCamera")

local FadingCamera = {}
FadingCamera.ClassName = "FadingCamera"

function FadingCamera.new(Camera)
	local self = setmetatable({}, FadingCamera)

	self.Spring = Spring.new(0)

	self.Camera = Camera or error("No camera")
	self.Damper = 1
	self.Speed = 15

	return self
end

function FadingCamera:__newindex(Index, Value)
	if Index == "Damper" then
		self.Spring.Damper = Value
	elseif Index == "Value" then
		self.Spring.Value = Value
	elseif Index == "Speed" then
		self.Spring.Speed = Value
	elseif Index == "Target" then
		self.Spring.Target = Value
	elseif Index == "Spring" or Index == "Camera" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of fading camera")
	end
end

function FadingCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return (self.Camera.CameraState or self.Camera) * self.Spring.Value
	elseif Index == "Damper" then
		return self.Spring.Damper
	elseif Index == "Value" then
		return self.Spring.Value
	elseif Index == "Speed" then
		return self.Spring.Speed
	elseif Index == "Target" then
		return self.Spring.Target
	elseif Index == "Velocity" then
		return self.Spring.Velocity
	elseif Index == "HasReachedTarget" then
		return math.abs(self.Value - self.Target) < 1e-4 and math.abs(self.Velocity) < 1e-4
	else
		return FadingCamera[Index]
	end
end

return FadingCamera