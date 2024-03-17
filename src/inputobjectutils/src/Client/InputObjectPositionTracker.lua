--[=[
	@class InputObjectPositionTracker
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local InputObjectUtils = require("InputObjectUtils")
local InputObjectRayUtils = require("InputObjectRayUtils")

local InputObjectPositionTracker = setmetatable({}, BaseObject)
InputObjectPositionTracker.ClassName = "InputObjectPositionTracker"
InputObjectPositionTracker.__index = InputObjectPositionTracker

function InputObjectPositionTracker.new(initialInputObject)
	assert(typeof(initialInputObject) == "Instance" and initialInputObject:IsA("InputObject"), "Bad initialInputObject")

	local self = setmetatable(BaseObject.new(), InputObjectPositionTracker)

	self._initialInputObject = assert(initialInputObject, "No initialInputObject")

	if InputObjectUtils.isMouseUserInputType(self._initialInputObject.UserInputType) then
		self._lastMousePosition = self._initialInputObject.Position
		self._isMouse = true

		self._maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject)
			if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
				self._lastMousePosition = inputObject.Position
			end
		end))

		self._maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
			if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
				self._lastMousePosition = inputObject.Position
			end
		end))

		self._maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
			if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
				self._lastMousePosition = inputObject.Position
			end
		end))
	end

	return self
end

function InputObjectPositionTracker:GetInputObjectPosition()
	if self._isMouse then
		return self._lastMousePosition
	else
		local position = self._initialInputObject.Position
		return Vector2.new(position.x, position.y)
	end
end

function InputObjectPositionTracker:GetInputObjectRay(distance)
	distance = distance or 1000

	if self._isMouse then
		return InputObjectRayUtils.cameraRayFromScreenPosition(self._lastMousePosition, distance, Workspace.CurrentCamera)
	else
		return InputObjectRayUtils.cameraRayFromInputObject(self._initialInputObject, distance, Vector2.zero, Workspace.CurrentCamera)
	end
end

return InputObjectPositionTracker