--[=[
	Tracks an input object, whether it's a mouse or a touch button for position
	or mouse down.

	Works around a bug in the mouse object where the mouse input objects are new
	per a mouse event.

	```lua
	local maid = Maid.new()
	local tracker = maid:Add(InputObjectTracker.new(initialInputObject))

	maid:GiveTask(RunService.RenderStepped:Connect(function()
		print("Input down at", tracker:GetPosition())

		-- Can also cast a ray
		print("Cast ray at", tracker:GetRay())
	end))

	maid:GiveTask(tracker:ObserveInputEnded():Subscribe(function()
		maid:DoCleaning()
	end))

	maid:GiveTask(tracker.InputEnded:Connect(function()

	end))
	```

	@class InputObjectTracker
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local InputObjectUtils = require("InputObjectUtils")
local InputObjectRayUtils = require("InputObjectRayUtils")
local RxInputObjectUtils = require("RxInputObjectUtils")
local RxSignal = require("RxSignal")

local InputObjectTracker = setmetatable({}, BaseObject)
InputObjectTracker.ClassName = "InputObjectTracker"
InputObjectTracker.__index = InputObjectTracker

function InputObjectTracker.new(initialInputObject)
	assert(typeof(initialInputObject) == "Instance" and initialInputObject:IsA("InputObject"), "Bad initialInputObject")

	local self = setmetatable(BaseObject.new(), InputObjectTracker)

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

	self._initialPosition = self:GetPosition()

	self.InputEnded = RxSignal.new(self:ObserveInputEnded())

	return self
end

--[=[
	Observes when the input is ended

	@return Observable
]=]
function InputObjectTracker:ObserveInputEnded()
	return RxInputObjectUtils.observeInputObjectEnded(self._initialInputObject)
end

--[=[
	Gets the initial position for the input object

	@return Vector2
]=]
function InputObjectTracker:GetInitialPosition()
	return self._initialPosition
end

--[=[
	Observes input object position

	@return Observable<Vector2>
]=]
function InputObjectTracker:GetPosition()
	if self._isMouse then
		return self._lastMousePosition
	else
		local position = self._initialInputObject.Position
		return Vector2.new(position.x, position.y)
	end
end

--[=[
	Observes the input object ray

	@param distance number? -- Optional number, defaults to 1000
	@return Observable<Vector2>
]=]
function InputObjectTracker:GetRay(distance)
	distance = distance or 1000

	if self._isMouse then
		return InputObjectRayUtils.cameraRayFromScreenPosition(self._lastMousePosition, distance, self._camera or Workspace.CurrentCamera)
	else
		return InputObjectRayUtils.cameraRayFromInputObject(self._initialInputObject, distance, Vector2.zero, self._camera or Workspace.CurrentCamera)
	end
end

--[=[
	Sets the camera for the input object tracker to retrieve rays from

	@param camera Camera
]=]
function InputObjectTracker:SetCamera(camera)
	assert(typeof(camera) == "Instance", "Bad camera")

	self._camera = camera
end

return InputObjectTracker