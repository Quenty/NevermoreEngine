--!strict
--[=[
	Provides a utility method to clearing selection images with blank values.
	@class SelectionImageUtils
]=]

local SelectionImageUtils = {}

function SelectionImageUtils.overrideWithBlank(button: GuiButton): ImageLabel
	local selectionImage = Instance.new("ImageLabel")
	selectionImage.Image = ""
	selectionImage.Size = UDim2.new(0, 100, 0, 100)
	selectionImage.BackgroundTransparency = 1
	selectionImage.BorderSizePixel = 0
	selectionImage.Visible = true
	selectionImage.Name = "SelectionImage"

	button.SelectionImageObject = selectionImage

	return selectionImage
end

return SelectionImageUtils