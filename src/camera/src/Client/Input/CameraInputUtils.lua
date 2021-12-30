--[=[
	@class CameraInputUtils
]=]

local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local CameraInputUtils = {}

function CameraInputUtils.getPanBy(panDelta, sensivity)
	local viewportSize = Workspace.CurrentCamera.ViewportSize
	local aspectRatio = CameraInputUtils.getCappedAspectRatio(viewportSize)
	local inversionVector = CameraInputUtils.getInversionVector(UserGameSettings)

	if CameraInputUtils.isPortraitMode(aspectRatio) then
		sensivity = CameraInputUtils.invertSensitivity(sensivity)
	end

	return inversionVector*sensivity*panDelta
end

function CameraInputUtils.convertToPanDelta(vector3)
	return Vector2.new(vector3.x, vector3.y)
end

function CameraInputUtils.getInversionVector(userGameSettings)
	return Vector2.new(1, userGameSettings:GetCameraYInvertValue())
end

function CameraInputUtils.invertSensitivity(sensivity)
	return Vector2.new(sensivity.y, sensivity.x)
end

function CameraInputUtils.isPortraitMode(aspectRatio)
	if aspectRatio < 1 then
		return true
	end

	return false
end

function CameraInputUtils.getCappedAspectRatio(viewportSize)
	local x = math.clamp(viewportSize.x, 0, 1920)
	local y = math.clamp(viewportSize.y, 0, 1080)
	return x/y
end

return CameraInputUtils