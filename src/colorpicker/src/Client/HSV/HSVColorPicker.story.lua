--[[
	@class HSVColorPicker.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local HSVColorPicker = require("HSVColorPicker")

return function(target)
	local maid = Maid.new()

	local picker = maid:Add(HSVColorPicker.new())
	picker:SetColor(Color3.new(0.5, 0.8, 0.3))
	picker.Gui.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Gui.Position = UDim2.fromScale(0.5, 0.5);
	picker.Gui.Size = UDim2.fromScale(0.8, 0.8)
	picker.Gui.Parent = target

	return function()
		maid:DoCleaning()
	end
end