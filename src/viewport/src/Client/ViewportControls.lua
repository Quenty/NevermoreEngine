--[=[
	Controls for [Viewport]
	@class ViewportControls
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local InputObjectUtils = require("InputObjectUtils")
local ValueObject = require("ValueObject")

local SENSITIVITY = Vector2.new(8, 4)

local ViewportControls = setmetatable({}, BaseObject)
ViewportControls.ClassName = "ViewportControls"
ViewportControls.__index = ViewportControls

--[=[
    Create the controls for dragging.
    @param viewport Instance
    @param viewportModel Viewport
    @return BaseObject
]=]
function ViewportControls.new(viewport: ViewportFrame, viewportModel)
	local self = setmetatable(BaseObject.new(viewport), ViewportControls)

	self._viewportModel = assert(viewportModel, "No rotationYaw")
	self._enabled = self._maid:Add(ValueObject.new(true, "boolean"))

	self._maid:GiveTask(self._obj.InputBegan:Connect(function(inputObject)
		if
			(
				inputObject.UserInputType == Enum.UserInputType.MouseButton1
				or inputObject.UserInputType == Enum.UserInputType.MouseButton2
				or inputObject.UserInputType == Enum.UserInputType.Touch
			) and self._enabled.Value
		then
			self:_startDrag(inputObject)
		end
	end))

	return self
end

--[=[
	Sets the enabled state of the controls

	@param enabled boolean
]=]
function ViewportControls:SetEnabled(enabled: boolean)
	assert(type(enabled) == "boolean", "Bad enabled")

	self._enabled.Value = enabled
end

function ViewportControls:_startDrag(startInputObject: InputObject)
	if self._maid._dragging then
		return
	end

	local maid = Maid.new()

	local lastPosition = startInputObject.Position

	maid:GiveTask(startInputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
		if startInputObject.UserInputState == Enum.UserInputState.End then
			self:_stopDrag()
		end
	end))

	local lastDelta
	maid:GiveTask(self._obj.InputChanged:Connect(function(inputObject)
		if InputObjectUtils.isSameInputObject(inputObject, startInputObject) or inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			local position = inputObject.Position
			local delta = lastPosition - position
			lastPosition = position

			local absSize = self._obj.AbsoluteSize
			local deltaV2 = Vector2.new(delta.x, delta.y)/absSize * SENSITIVITY
			lastDelta = deltaV2

			self._viewportModel:RotateBy(deltaV2, true)
		end
	end))

	maid:GiveTask(function()
		if not self._viewportModel.Destroy then
			return
		end

		-- Compute rotation
		if lastDelta then
			self._viewportModel:RotateBy(lastDelta)
		end
	end)

	maid:GiveTask(self._obj.InputEnded:Connect(function(inputObject)
		if InputObjectUtils.isSameInputObject(inputObject, startInputObject) then
			self:_stopDrag()
		end
	end))

	self._maid._dragging = maid
end

function ViewportControls:_stopDrag()
	self._maid._dragging = nil
end

return ViewportControls
