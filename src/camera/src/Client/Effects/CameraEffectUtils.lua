--[=[
	A CameraEffect is something that can be resolved into a CameraState providing source
	@class CameraEffectUtils
]=]

--[=[
	Represents an effect that can be used in combination with other effects.
	@interface CameraEffect
	.CameraState CameraState
	@within CameraEffectUtils
]=]

--[=[
	Something that is like a camera
	@type CameraLike CameraEffect | CameraState
	@within CameraEffectUtils
]=]

return {}