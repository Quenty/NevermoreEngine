--[=[
	Gets the relative move direction from the camera and the humanoid allowing Roblox's input system to
	be layered on top of a camera system.

	Ever wanted to not rewrite all of Roblox's input systems! Well, now you can with this slight hack!

	@class HumanoidMoveDirectionUtils
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local getRotationInXZPlane = require("getRotationInXZPlane")

local ZERO_VECTOR = Vector3.zero
local RIGHT = Vector3.new(1, 0, 0)
local DIRECTION_INPUT_MAPS = {
	[Enum.KeyCode.Left] = -RIGHT;
	[Enum.KeyCode.Right] = RIGHT;
}

local HumanoidMoveDirectionUtils = {}

--[=[
	Gets the relative move direction from the camera and the humanoid.

	This is absolutely a hack.

	@param cameraCFrame CFrame
	@param humanoid Humanoid
	@return Vector3
]=]
function HumanoidMoveDirectionUtils.getRelativeMoveDirection(cameraCFrame, humanoid)
	if UserInputService:GetFocusedTextBox() then
		return ZERO_VECTOR
	end

	local moveDirection = humanoid.MoveDirection
	local flatCameraCFrame = getRotationInXZPlane(cameraCFrame)

	local relative = flatCameraCFrame:vectorToObjectSpace(moveDirection)

	-- Compensate for lack of camera movement in left/right arrow keys
	local direction = ZERO_VECTOR
	for keycode, add in DIRECTION_INPUT_MAPS do
		if UserInputService:IsKeyDown(keycode) then
			direction = direction + add
		end
	end
	if direction.magnitude > 0 then
		return (relative + direction.unit).unit
	end

	return relative
end

return HumanoidMoveDirectionUtils