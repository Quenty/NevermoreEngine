---
-- @module Blend.story
-- @author Quenty

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	local percentVisible = Blend.State(0)
	local state = Blend.State("a")
	maid:GiveTask(state)

	maid:GiveTask((Blend.New "TextLabel" {
		Parent = target;
		Size = Blend.Computed(percentVisible, function(visible)
			return UDim2.new(0, visible*100, 0, 50);
		end);
		BackgroundTransparency = Blend.Computed(percentVisible, function(visible)
			return 1 - visible
		end);
		Position = UDim2.new(0.5, 0, 0.5, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		Text = state;
		TextScaled = true;

		[Blend.Children] = {
			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 5);
			};

			{
				Blend.Computed(percentVisible, function(visible)
					local results = {}

					-- constructs a ton of children everytime this changes
					for x=0, visible*100, 10 do
						table.insert(results, Blend.New "Frame" {
							Size = UDim2.new(0, 6, 0, 6);
							Position = UDim2.new(0, x, 0.9, 0);
							AnchorPoint = Vector2.new(0.5, 0.5);
							BorderSizePixel = 0;
							BackgroundColor3 = Color3.new(x/100, 0.5, 0.5);

							[Blend.Children] = {
								Blend.New "UICorner" {
									CornerRadius = UDim.new(0.5, 5);
								};
							};
						})
					end

					return results
				end);
			};
		};
	}):Subscribe())

	local PERIOD = 5
	maid:GiveTask(RunService.RenderStepped:Connect(function()
		state.Value = tostring(os.clock())
		percentVisible.Value = (math.sin(os.clock()*math.pi*2/PERIOD) + 1)/2
	end))

	return function()
		maid:DoCleaning()
	end
end