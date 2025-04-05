--!strict
--[=[
	Utility method to transfer camera info to and from the client.

	@class CameraInfoUtils
]=]

local CameraInfoUtils = {}

export type CameraInfo = {
	cframe: CFrame,
	viewPortSize: Vector2,
	fieldOfView: number,
}

--[=[
	Creates a new camera info.

	@param cframe CFrame
	@param viewPortSize Vector2
	@param fieldOfView number
	@return CameraInfo
]=]
function CameraInfoUtils.createCameraInfo(cframe: CFrame, viewPortSize: Vector2, fieldOfView: number): CameraInfo
	assert(typeof(cframe) == "CFrame", "Bad cframe")
	assert(typeof(viewPortSize) == "Vector2", "Bad viewPortSize")
	assert(type(fieldOfView) == "number", "Bad fieldOfView")

	return {
		cframe = cframe,
		viewPortSize = viewPortSize,
		fieldOfView = fieldOfView,
	}
end

--[=[
	Creates a new camera info from a camera.

	@param camera Camera
	@return CameraInfo
]=]
function CameraInfoUtils.fromCamera(camera: Camera): CameraInfo
	return CameraInfoUtils.createCameraInfo(camera.CFrame, camera.ViewportSize, camera.FieldOfView)
end


--[=[
	Returns true if the value is a cameraInfo

	@param cameraInfo any
	@return boolean
]=]
function CameraInfoUtils.isCameraInfo(cameraInfo: any):  boolean
	return type(cameraInfo) == "table"
		and typeof(cameraInfo.cframe) == "CFrame"
		and typeof((cameraInfo :: any).viewPortSize) == "Vector2"
		and type((cameraInfo :: any).fieldOfView) == "number"
end


return CameraInfoUtils