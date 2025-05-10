--!strict
--[=[
	Utility methods for cameras. These are great for viewport frames.

	```lua
	-- Sample viewport frame fitting of a model
	local viewportFrame = ...
	local camera = viewportFrame.CurrentCamera
	local model = viewportFrame:FindFirstChildWhichIsA("Model")

	RunService.RenderStepped:Connect(function()
		local cframe, size = model:GetBoundingBox()
		local size = viewportFrame.AbsoluteSize
		local aspectRatio = size.x/size.y
		local dist = CameraUtils.fitBoundingBoxToCamera(size, camera.FieldOfView, aspectRatio)
		camera.CFrame = cframe.Position + CFrame.Angles(0, math.pi*os.clock() % math.pi, -math.pi/8)
			:vectorToWorldSpace(Vector3.new(0, 0, -dist))
	end)
	```

	@class CameraUtils
]=]

local CameraUtils = {}

--[=[
	Computes the diameter of a cubeid

	@param size Vector3
	@return number
]=]
function CameraUtils.getCubeoidDiameter(size: Vector3): number
	local x = size.X
	local y = size.Y
	local z = size.Z

	return math.sqrt(x * x + y * y + z * z)
end

--[=[
	Use spherical bounding box to calculate how far back to move a camera
	See: https://community.khronos.org/t/zoom-to-fit-screen/59857/12

	@param size Vector3 -- Size of the bounding box
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtils.fitBoundingBoxToCamera(size: Vector3, fovDeg: number, aspectRatio: number): number
	local radius = CameraUtils.getCubeoidDiameter(size) / 2
	return CameraUtils.fitSphereToCamera(radius, fovDeg, aspectRatio)
end

--[=[
	Fits a sphere to the camera, computing how far back to zoom the camera from
	the center of the sphere.

	@param radius number -- Radius of the sphere
	@param fovDeg number -- Field of view in degrees (vertical)
	@param aspectRatio number -- Aspect ratio of the screen
	@return number -- Distance to move the camera back from the bounding box
]=]
function CameraUtils.fitSphereToCamera(radius: number, fovDeg: number, aspectRatio: number): number
	local halfFov = 0.5 * math.rad(fovDeg)
	if aspectRatio < 1 then
		halfFov = math.atan(aspectRatio * math.tan(halfFov))
	end

	return radius / math.sin(halfFov)
end

--[=[
	Checks if a position is on screen on a camera

	@param camera Camera
	@param position Vector3
	@return boolean
]=]
function CameraUtils.isOnScreen(camera: Camera, position: Vector3): boolean
	local _, onScreen = camera:WorldToScreenPoint(position)
	return onScreen
end

return CameraUtils
