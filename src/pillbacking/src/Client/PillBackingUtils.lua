--!strict
--[=[
	Utilities for working with pill backings
	@class PillBackingUtils
]=]

local PillBackingUtils = {}

function PillBackingUtils.setBackgroundColor(backing: Frame, color3: Color3)
	assert(backing:IsA("Frame"))
	backing.BackgroundColor3 = color3
	for _, item in backing:GetChildren() do
		if item:IsA("ImageLabel") then
			item.ImageColor3 = color3
		end
	end
end

function PillBackingUtils.setTransparency(backing: Frame, transparency: number)
	assert(backing:IsA("Frame"))
	backing.BackgroundTransparency = transparency
	for _, child in backing:GetChildren() do
		if child:IsA("ImageLabel") then
			child.ImageTransparency = transparency
		end
	end
end

function PillBackingUtils.setShadowTransparency(shadow: ImageLabel, transparency: number)
	shadow.ImageTransparency = transparency
	for _, child in shadow:GetChildren() do
		if child:IsA("ImageLabel") then
			child.ImageTransparency = transparency
		end
	end
end

return PillBackingUtils
