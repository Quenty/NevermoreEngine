--[[
	@class PluginPane.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")

local ConverterPane = require("ConverterPane")

return function(target)
	local maid = Maid.new()

	local pane = ConverterPane.new()
	maid:GiveTask(pane)

	pane:SetSelected(game.Selection:Get())

	maid:GiveTask(game.Selection.SelectionChanged:Connect(function()
		pane:SetSelected(game.Selection:Get())
	end))

	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	return function()
		maid:DoCleaning()
	end
end