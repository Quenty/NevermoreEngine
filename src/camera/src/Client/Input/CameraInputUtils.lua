--!strict
--[=[
	@class CameraInputUtils
]=]

local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local CameraInputUtils = {}

--[=[
	Computes the pan delta based on the given pan delta and sensitivity.

	@param panDelta Vector2
	@param sensivity Vector2
	@return Vector2
]=]
function CameraInputUtils.getPanBy(panDelta: Vector2, sensivity: Vector2): Vector2
	local viewportSize = Workspace.CurrentCamera.ViewportSize
	local aspectRatio = CameraInputUtils.getCappedAspectRatio(viewportSize)
	local inversionVector = CameraInputUtils.getInversionVector(UserGameSettings)

	if CameraInputUtils.isPortraitMode(aspectRatio) then
		sensivity = CameraInputUtils.invertSensitivity(sensivity)
	end

	return inversionVector * sensivity * panDelta
end

--[=[
	Converts a Vector3 to a Vector2 for camera panning

	@param vector3 Vector3
	@return Vector2
]=]
function CameraInputUtils.convertToPanDelta(vector3: Vector3): Vector2
	return Vector2.new(vector3.X, vector3.Y)
end

--[=[
	Returns the inversion vector based on the user game settings.

	@param userGameSettings UserGameSettings
	@return Vector2
]=]
function CameraInputUtils.getInversionVector(userGameSettings: UserGameSettings): Vector2
	return Vector2.new(1, userGameSettings:GetCameraYInvertValue())
end

--[=[
	Inverts the sensitivity vector.

	@param sensivity Vector2
	@return Vector2
]=]
function CameraInputUtils.invertSensitivity(sensivity: Vector2): Vector2
	return Vector2.new(sensivity.Y, sensivity.X)
end

--[=[
	Returns true if in portrait mode, false otherwise.
	@param aspectRatio number
	@return boolean
]=]
function CameraInputUtils.isPortraitMode(aspectRatio: number): boolean
	if aspectRatio < 1 then
		return true
	end

	return false
end

--[=[
	Computes a capped aspect ratio based on the viewport size.
	@param viewportSize Vector2
	@return number
]=]
function CameraInputUtils.getCappedAspectRatio(viewportSize: Vector2): number
	local x = math.clamp(viewportSize.X, 0, 1920)
	local y = math.clamp(viewportSize.Y, 0, 1080)
	return x / y
end

return CameraInputUtils
