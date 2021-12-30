-- Main injection point

local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local Blend = require(packages.Blend)


local state = Blend.State("a")

Blend.New "ScreenGui" {
	Parent = require(packages.PlayerGuiUtils).getPlayerGui();
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