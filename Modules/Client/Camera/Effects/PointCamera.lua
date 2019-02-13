--- Point a current element
-- @classmod PointCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local PointCamera = {}
PointCamera.ClassName = "PointCamera"

---
-- @constructor
-- @param originCamera A camera to use
-- @param focusCamera The Camera to look at.
function PointCamera.new(originCamera, focusCamera)
	local self = setmetatable({}, PointCamera)

	self.OriginCamera = originCamera or error("Must have originCamera")
	self.FocusCamera = focusCamera or error("Must have focusCamera")

	return self
end

function PointCamera:__add(other)
	return SummedCamera.new(self, other)
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

		State.CFrame = CFrame.new(
			Origin.Position,
			Focus.Position)

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