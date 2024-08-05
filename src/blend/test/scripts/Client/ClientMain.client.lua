--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("blend"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local Blend = require("Blend")
local PlayerGuiUtils = require("PlayerGuiUtils")

local state = Blend.State("a")

Blend.New "ScreenGui" {
	Parent = PlayerGuiUtils.getPlayerGui();
	[Blend.Children] = {
		Blend.New "TextLabel" {
			Size = UDim2.new(0, 100, 0, 50);
			Position = UDim2.new(0.5, 0, 0.5, 0);
			AnchorPoint = Vector2.new(0.5, 0.5);
			Text = state;
		}
	};
}

state.Value = "hi"