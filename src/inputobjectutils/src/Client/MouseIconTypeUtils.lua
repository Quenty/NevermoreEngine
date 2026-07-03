--!strict
--[=[
    @class MouseIconTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerGuiUtils = require("PlayerGuiUtils")

local MouseIconTypeUtils = {}

export type IconType = "arrow" | "openhand" | "ibeam" | "closedhand"

function MouseIconTypeUtils.getIconUnderPosition(position: Vector2): IconType
	local playerGui = PlayerGuiUtils.getPlayerGui()
	if not playerGui then
		return "arrow"
	end

	local guiObjects = playerGui:GetGuiObjectsAtPosition(position.X, position.Y)
	for _, guiObject in guiObjects do
		if guiObject:IsA("TextBox") then
			if guiObject.GuiState == Enum.GuiState.Hover or guiObject.GuiState == Enum.GuiState.Press then
				return "ibeam"
			end
		elseif guiObject:IsA("ImageButton") or guiObject:IsA("TextButton") then
			if guiObject.GuiState == Enum.GuiState.Hover or guiObject.GuiState == Enum.GuiState.Press then
				return "openhand"
			end
		end
	end

	return "arrow"
end

function MouseIconTypeUtils.getDefaultIconAssetForType(iconType: IconType): string
	if iconType == "arrow" then
		return "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
	elseif iconType == "openhand" then
		return "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
	elseif iconType == "closedhand" then
		return "rbxasset://textures/Cursors/DragDetector/ActivatedCursor.png"
	elseif iconType == "ibeam" then
		return "rbxasset://textures/Cursors/KeyboardMouse/IBeamCursor.png"
	else
		error("Unknown icon type: " .. tostring(iconType))
	end
end

return MouseIconTypeUtils
