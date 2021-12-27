--[=[
	Add another layer of effects that can be faded in/out
	@class FadingCamera
]=]

local require = require(script.Parent.loader).load(script)

local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local FadingCamera = {}
FadingCamera.ClassName = "FadingCamera"

--[=[
	@param camera CameraEffect
]=]
function FadingCamera.new(camera)
	local self = setmetatable({}, FadingCamera)

	self.Spring = Spring.new(0)

	self.Camera = camera or error("No camera")
	self.Damper = 1
	self.Speed = 15

	return self
end

function FadingCamera:__add(other)
	return SummedCamera.new(self, other)
end

function FadingCamera:__newindex(index, value)
	if index == "Damper" then
		self.Spring.Damper = value
	elseif index == "value" then
		self.Spring.Value = value
	elseif index == "Speed" then
		self.Spring.Speed = value
	elseif index == "Target" then
		self.Spring.Target = value
	elseif index == "Spring" or index == "Camera" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of fading camera")
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadingCamera
]=]
function FadingCamera:__index(index)
	if index == "CameraState" then
		return (self.Camera.CameraState or self.Camera) * self.Spring.Value
	elseif index == "Damper" then
		return self.Spring.Damper
	elseif index == "value" then
		return self.Spring.Value
	elseif index == "Speed" then
		return self.Spring.Speed
	elseif index == "Target" then
		return self.Spring.Target
	elseif index == "Velocity" then
		return self.Spring.Velocity
	elseif index == "HasReachedTarget" then
		return math.abs(self.Value - self.Target) < 1e-4 and math.abs(self.Velocity) < 1e-4
	else
		return FadingCamera[index]
	end
end

return FadingCamera