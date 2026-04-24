--!strict
--[=[
    @class MousePositionUtils
]=]

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local InputObjectUtils = require("InputObjectUtils")
local Maid = require("Maid")
local Observable = require("Observable")

local MousePositionUtils = {}

local function toVector2(vector3: Vector3): Vector2
	return Vector2.new(vector3.X, vector3.Y)
end

--[=[
    Converts an InputObject to a mouse position if it's a mouse input, otherwise returns nil.
]=]
function MousePositionUtils.mouseUserInputObjectToMousePosition(inputObject: InputObject): Vector2?
	if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
		return toVector2(inputObject.Position)
	else
		return nil
	end
end

--[=[
    Observes the mouse position based on UserInputService events. Optionally takes an initial InputObject to seed the position.
]=]
function MousePositionUtils.observeMousePosition(initialInputObject: InputObject?): Observable.Observable<Vector2>
	return Observable.new(function(sub)
		local maid = Maid.new()
		local lastMousePosition: Vector2? = nil

		local function setMousePosition(position: Vector2)
			if lastMousePosition ~= position then
				lastMousePosition = position
				sub:Fire(position)
			end
		end

		maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject)
			local position = MousePositionUtils.mouseUserInputObjectToMousePosition(inputObject)
			if position then
				setMousePosition(position)
			end
		end))

		maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
			local position = MousePositionUtils.mouseUserInputObjectToMousePosition(inputObject)
			if position then
				setMousePosition(position)
			end
		end))

		maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
			local position = MousePositionUtils.mouseUserInputObjectToMousePosition(inputObject)
			if position then
				setMousePosition(position)
			end
		end))

		local initial = if initialInputObject
			then MousePositionUtils.mouseUserInputObjectToMousePosition(initialInputObject)
			else nil
		if initial then
			setMousePosition(initial)
		else
			setMousePosition(MousePositionUtils.queryMousePositionFromUserInputService())
		end

		return function()
			maid:DoCleaning()
		end
	end) :: any
end

--[=[
    Gets the same mouse position as we'd get from :GetMouse() call, with the gui insets accounted for
]=]
function MousePositionUtils.queryMousePositionFromUserInputService(): Vector2
	local guiInsetTopLeft = GuiService:GetGuiInset()
	local location = UserInputService:GetMouseLocation()
	return Vector2.new(location.X + guiInsetTopLeft.x, location.Y + guiInsetTopLeft.y)
end

function MousePositionUtils._queryMousePositionFromLocalPlayer(): Vector2?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end

	local mouse = localPlayer:GetMouse()
	if not mouse then
		return nil
	end

	return Vector2.new(mouse.X, mouse.Y)
end

return MousePositionUtils
