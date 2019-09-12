--- Utilities for working with pill backings
-- @module PillBackingUtils

local PillBackingUtils = {}

function PillBackingUtils.setBackgroundColor(backing, color3)
	backing.BackgroundColor3 = color3
	for _, item in pairs(backing:GetChildren()) do
		if item:IsA("ImageLabel") then
			item.ImageColor3 = color3
		end
	end
end

function PillBackingUtils.setTransparency(backing, transparency)
	backing.BackgroundTransparency = transparency
	for _, child in pairs(backing:GetChildren()) do
		if child:IsA("ImageLabel") then
			child.ImageTransparency = transparency
		end
	end
end

function PillBackingUtils.setShadowTransparency(shadow, transparency)
	shadow.ImageTransparency = transparency
	for _, child in pairs(shadow:GetChildren()) do
		if child:IsA("ImageLabel") then
			child.ImageTransparency = transparency
		end
	end
end

return PillBackingUtils