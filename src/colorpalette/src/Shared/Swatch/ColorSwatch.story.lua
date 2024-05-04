--[[
	@class ColorSwatch.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Maid = require("Maid")
local Blend = require("Blend")
local ColorSwatch = require("ColorSwatch")

return function(target)
	local maid = Maid.new()

	local function entry(color, text, isBaseColor)
		return Blend.New "Frame" {
			Name = "Entry";
			Size = UDim2.new(0, 25, 0, 45);
			BackgroundTransparency = 1;

			[Blend.Children] = {
				Blend.New "Frame" {
					BackgroundColor3 = color;
					Size = UDim2.new(0, 25, 0, 25);
				};

				Blend.New "TextLabel" {
					Text = tostring(text);
					Size = UDim2.new(1, 0, 0, 15);
					Position = UDim2.new(0, 0, 1, 0);
					AnchorPoint = Vector2.new(0, 1);
					Font = Enum.Font.Code;
					TextScaled = true;

					[Blend.Children] = {
						Blend.New "UIStroke" {
							Color = Color3.new(0.6, 1, 0.6);
							Thickness = isBaseColor and 3 or 0;
						};
					}
				};
			};
		};
	end


	local function palette(color)
		local grades = {}

		local colorSwatch = ColorSwatch.new(color, 1)

		for i=0, 100, 10 do
			table.insert(grades, entry(colorSwatch:GetGraded(i), tostring(i), math.abs(colorSwatch:GetBaseGrade() - i) <= 5))
		end

		return Blend.New "Frame" {
			Size = UDim2.new(1, 0, 0, 45);
			[Blend.Children] = {
				grades;
				Blend.New "UIListLayout" {
					Padding = UDim.new(0, 0);
					HorizontalAlignment = Enum.HorizontalAlignment.Center;
					VerticalAlignment = Enum.VerticalAlignment.Center;
					FillDirection = Enum.FillDirection.Horizontal;
				}
			}
		}
	end


	maid:GiveTask((Blend.New "ScrollingFrame" {
		Size = UDim2.new(1, 0, 1, 0);
		Parent = target;
		[Blend.Children] = {
			palette(Color3.new(0, 0, 0));
			-- palette(Color3.new(1, 1, 1));
			-- palette(Color3.new(0.5, 0.5, 0.5));
			palette(Color3.fromRGB(117, 117, 117));
			palette(Color3.fromRGB(245, 238, 214));
			palette(Color3.fromRGB(96, 58, 58));
			palette(Color3.fromRGB(85, 170, 127));
			palette(Color3.new(1, 0, 0));
			palette(Color3.new(0, 1, 0));
			palette(Color3.new(0, 0, 1));
			palette(Color3.new(1, 0, 1));
			palette(Color3.new(1, 1, 0));
			palette(Color3.new(0, 1, 1));

			Blend.New "UIListLayout" {
				Padding = UDim.new(0, 5);
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				VerticalAlignment = Enum.VerticalAlignment.Top;
				FillDirection = Enum.FillDirection.Vertical;
			};

			Blend.New "UIPadding" {
				PaddingTop = UDim.new(0, 10);
			};
		}
	}):Subscribe())

	return function()
		maid:DoCleaning()
	end
end