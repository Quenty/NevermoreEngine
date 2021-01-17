---
-- @module SelectionImageUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DialogTemplatesClient = require("DialogTemplatesClient")

local SelectionImageUtils = {}

function SelectionImageUtils.overrideWithBlank(button)
	local selectionImage = DialogTemplatesClient:Clone("BlankSelectionImageObjectTemplate")

	button.SelectionImageObject = selectionImage

	return selectionImage
end

return SelectionImageUtils